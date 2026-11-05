"""Worked examples and independent invariants; no live operational data."""
from collections import Counter
import copy
import math
import random
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'services/operations'))
from ww_ops.contracts import OpError
from ww_ops.lenses import project, differences
from ww_ops.temporal import iso, ticks, MICROSECOND

SCOPE = {'organization': 'math-fixture', 'instance': 'local', 'profile': 'test'}
BASE = ticks('2026-11-01T00:00:00Z')


def event(sequence, seconds, kind='source.opened', obj='item', actor='alpha', **extra):
    return {'id': 'e' + str(sequence), 'sequence': sequence, 'scope': SCOPE, 'type': kind,
            'object': obj, 'actor': actor, 'occurred_at': iso(BASE + round(seconds * MICROSECOND)),
            'recorded_at': iso(BASE + round(seconds * MICROSECOND)), 'category': 'observation',
            'producer': 'fixture', 'data': {}, **extra}


def attempt_events(intervals):
    events = []
    for index, (actor, start, end) in enumerate(intervals):
        identity = 'attempt-' + str(index)
        data = {'attempt': identity, 'assignment': 'shared', 'started_at': iso(BASE + start * MICROSECOND)}
        events.append(event(len(events) + 1, start, 'attempt.started', identity, actor,
                            producer='ww-operations', data=data))
        if end is not None:
            events.append(event(len(events) + 1, end, 'attempt.finished', identity, actor,
                                producer='ww-operations', data={**data, 'ended_at': iso(BASE + end * MICROSECOND), 'status': 'succeeded'}))
    return events


class LensMathematicsTests(unittest.TestCase):
    def lens(self, name, events, **parameters):
        return project(name, events, SCOPE, **parameters)

    def test_three_measures_of_overlap_are_distinct(self):
        events = attempt_events([('alpha', 0, 60), ('alpha', 30, 90), ('beta', 30, 90)])
        d = self.lens('bundy', events, as_of=iso(BASE + 100 * MICROSECOND))['data']
        self.assertEqual(180, d['total_seconds'])
        self.assertEqual(150, d['actor_seconds'])
        self.assertEqual(90, d['wall_covered_seconds'])
        self.assertEqual(3, d['peak_concurrent_attempts'])
        self.assertEqual('attempt-seconds', d['unit'])

    def test_randomized_duration_unions_match_independent_discrete_oracle(self):
        rng = random.Random(367)
        for _ in range(100):
            intervals = [(rng.choice(['alpha', 'beta']), rng.randrange(0, 19), rng.randrange(20, 40)) for _ in range(6)]
            events = attempt_events(intervals)
            d = self.lens('bundy', events, start=iso(BASE + 5 * MICROSECOND), end=iso(BASE + 30 * MICROSECOND),
                          as_of=iso(BASE + 60 * MICROSECOND))['data']
            cells = [(actor, t) for actor, start, end in intervals for t in range(max(5, start), min(30, end))]
            self.assertEqual(len(cells) * MICROSECOND, d['total_microseconds'])
            self.assertEqual(len(set(cells)), d['actor_seconds'])
            self.assertEqual(len({t for _, t in cells}), d['wall_covered_seconds'])
            self.assertEqual(max(Counter(t for _, t in cells).values()), d['peak_concurrent_attempts'])

    def test_microsecond_additivity_at_adjacent_window_boundaries(self):
        events = attempt_events([('alpha', 0, 1)])
        end = iso(BASE + MICROSECOND)
        left = self.lens('bundy', events, start=iso(BASE), end=iso(BASE + 333333), as_of=end)['data']
        right = self.lens('bundy', events, start=iso(BASE + 333333), end=end, as_of=end)['data']
        all_data = self.lens('bundy', events, as_of=end)['data']
        self.assertEqual(all_data['total_microseconds'], left['total_microseconds'] + right['total_microseconds'])

    def test_open_interval_as_of_ignores_future_finish_and_preserves_subject_filter(self):
        events = attempt_events([('alpha', 0, 60), ('beta', 0, 60)])
        result = self.lens('board', events, as_of=iso(BASE + 30 * MICROSECOND), object_id='shared')
        self.assertEqual(2, len(result['data']['rows']))
        self.assertTrue(all(r['duration_seconds'] == 30 for r in result['data']['rows']))
        self.assertEqual([], self.lens('board', events, as_of=iso(BASE + 60 * MICROSECOND))['data']['rows'])

    def test_count_conservation_boundary_and_derived_exclusion(self):
        events = [event(1, 0), event(2, 3599), event(3, 3600), event(4, 1200, category='derived')]
        options = {'start': iso(BASE), 'end': iso(BASE + 3600 * MICROSECOND)}
        felt = self.lens('felt', events, **options)
        self.assertEqual(2, sum(b['count'] for b in felt['data']['buckets']))
        hollerith = self.lens('hollerith', events, **options)
        self.assertEqual(3, sum(len(c['events']) for c in hollerith['data']['cells']))
        self.assertEqual(1, felt['meta']['excluded_from_activity'])
        self.assertEqual(3, len(self.lens('burroughs', events, **options)['data']['rows']))

    def test_finite_difference_worked_polynomial_and_missing_initial_conditions(self):
        events = []
        for hour, count in enumerate([1, 4, 9, 16]):
            events.extend([event(len(events) + i + 1, hour * 3600 + i) for i in range(count)])
        options = {'start': iso(BASE), 'end': iso(BASE + 4 * 3600 * MICROSECOND)}
        first = self.lens('felt', events, method='hourly-count-first-difference/v1', **options)
        second = self.lens('grant', events, method='hourly-count-second-difference/v1', **options)
        self.assertEqual([None, 3, 5, 7], [b['difference'] for b in first['data']['buckets']])
        self.assertEqual([None, None, 2, 2], [b['difference'] for b in second['data']['buckets']])
        with self.assertRaises(OpError):self.lens('felt', events, method='hourly-count-first-difference/v1')
        with self.assertRaises(OpError):self.lens('grant', events, method='hourly-count-second-difference/v1', start=iso(BASE + 1), end=options['end'])

    def test_empty_dense_count_bins_are_explicit_and_no_automatic_derivative_scaling(self):
        result = self.lens('felt', [event(1, 10)], method='hourly-count-first-difference/v1',
                           start=iso(BASE), end=iso(BASE + 3 * 3600 * MICROSECOND))
        self.assertEqual([1, 0, 0], [b['count'] for b in result['data']['buckets']])
        self.assertEqual([None, -1, 0], [b['difference'] for b in result['data']['buckets']])
        self.assertEqual('events per bucket-step', result['data']['unit'])

    def test_dey_entropy_and_rate_have_defined_units_and_bounds(self):
        events = [event(1, 1, 'a'), event(2, 2, 'b'), event(3, 3, 'a'), event(4, 4, 'b')]
        sample = self.lens('dey', events)['data']['samples'][0]
        self.assertEqual(4 / 300, sample['events_per_second'])
        self.assertEqual(1, sample['type_entropy_bits'])
        self.assertEqual(1, sample['type_evenness'])
        self.assertEqual(2, sample['type_richness'])
        self.assertNotIn('stability', sample)
        for count in range(1, 20):
            sample = self.lens('dey', [event(i + 1, i, 'type-' + str(i % count)) for i in range(30)])['data']['samples'][0]
            self.assertGreaterEqual(sample['type_entropy_bits'], 0)
            self.assertLessEqual(sample['type_entropy_bits'], math.log2(sample['type_richness']) + 1e-12)
            self.assertTrue(0 <= sample['type_evenness'] <= 1 + 1e-12)

    def test_cooper_preserves_absolute_rate_and_dates_and_is_not_independent(self):
        events = [event(1, 21600), event(2, 21601), event(3, 108000)]
        points = self.lens('cooper', events)['data']['points']
        samples = self.lens('dey', events)['data']['samples']
        self.assertEqual([s['events_per_second'] for s in samples], [p['radius'] for p in points])
        self.assertEqual(points[0]['angle'], points[1]['angle'])
        self.assertNotEqual(points[0]['at'], points[1]['at'])
        for point in points:
            self.assertAlmostEqual(point['radius'], math.hypot(point['x'], point['y']))
        self.assertEqual(2, points[0]['radius'] / points[1]['radius'])

    def test_missing_null_boolean_and_pointer_escaping_remain_distinct(self):
        result = differences({'a/b': None, 'flag': True}, {'flag': 1, 'x~y': None})
        indexed = {r['path']: r for r in result}
        self.assertEqual('remove', indexed['/a~1b']['operation'])
        self.assertTrue(indexed['/a~1b']['before_present'])
        self.assertFalse(indexed['/a~1b']['after_present'])
        self.assertEqual('add', indexed['/x~0y']['operation'])
        self.assertEqual('replace', indexed['/flag']['operation'])

    def test_reordering_and_equivalent_timezone_do_not_change_computations(self):
        events = [event(1, 0), event(2, 10), event(3, 3600)]
        original = self.lens('felt', events, start='2026-11-01T00:00:00Z')['data']
        self.assertEqual(original, self.lens('felt', list(reversed(events)), start='2026-10-31T20:00:00-04:00')['data'])
        events[0]['scope'] = {**SCOPE, 'profile': 'other'}
        with self.assertRaises(OpError):self.lens('felt', events)

    def test_pacioli_is_within_window_prefix_count_and_unknown_methods_are_refused(self):
        events = [event(1, 0), event(2, 10), event(3, 20)]
        rows = self.lens('pacioli', events, start=iso(BASE + 10 * MICROSECOND))['data']['rows']
        self.assertEqual([1, 2], [r['running_count'] for r in rows])
        with self.assertRaises(OpError):self.lens('felt', events, method='productivity/v1')


if __name__ == '__main__':unittest.main()
