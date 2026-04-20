# TimeWarrior Extensions Registry

Scanned from [github.com/topics/timewarrior](https://github.com/topics/timewarrior)
and [timewarrior.net/tools/](https://timewarrior.net/tools/).

Last updated: 2026-04-11

## Tier 1 — High Value (recommended for ww integration)

| Name | Author | Language | Stars | Description | Install | ww Integration |
|------|--------|----------|-------|-------------|---------|----------------|
| [timew-sync-server](https://github.com/niccokunzmann/timew-sync-server) | niccokunzmann | Go | — | TimeWarrior synchronization server | go install | Potential for multi-device sync |
| [timew-sync-client](https://github.com/niccokunzmann/timew-sync-client) | niccokunzmann | Python | — | TimeWarrior synchronization client | pip install | Pairs with sync server |
| [pomodoro-warriors](https://github.com/cf020031308/pomodoro-warriors) | cf020031308 | Python | 53 | Pomodoro timer with todo list integration | pip install | Pomodoro technique for focused work |
| [tock](https://github.com/nkaz001/tock) | nkaz001 | Go | — | Powerful time tracking CLI tool | go install | Alternative time tracking interface |
| [timew-billable](https://github.com/trev-dev/timew-billable) | trev-dev | Nim | 8 | Calculate billable hours from timew data | nimble install | Invoicing and billing reports |
| [billwarrior](https://github.com/sw00/billwarrior) | sw00 | Python | — | Generate LaTeX invoices from timew data | pip install | Professional invoice generation |

## Tier 2 — Useful Extensions

| Name | Author | Language | Description | Install |
|------|--------|----------|-------------|---------|
| [timewarrior-aggregate](https://github.com/rameshg87/timewarrior-aggregate) | rameshg87 | Python | Plan and monitor daily/weekly time budgets | pip install |
| [timewarrior-recap](https://github.com/cbe/timewarrior-recap) | cbe | — | Summarize hours per tag | copy script |
| [twtools](https://github.com/fradeve/twtools) | fradeve | Python | Enhanced timew functionality | pip install |
| [Timewarrior-Pomodoro](https://github.com/omarmohamedkh/Timewarrior-Pomodoro) | omarmohamedkh | Python | Pomodoro timer interface for timew | pip install |
| [timew-report](https://github.com/gkssjovi/timewarrior-extensions) | gkssjovi | Python | Custom report extensions | copy scripts |
| [timew-flextime](https://github.com/joemat/timewarrior-extensions) | joemat | Python | Flextime tracking and balance | copy scripts |

## Tier 3 — Shell/UI Integrations

| Name | Author | Language | Description |
|------|--------|----------|-------------|
| [timew-zsh](https://github.com/svenXY/timewarrior) | svenXY | Shell | Zsh plugin with aliases and completion |
| [timew-bash-completion](https://github.com/GothenburgBitFactory/timewarrior) | GBF | Shell | Official bash completion |
| [timew-gnome-indicator](https://github.com/niccokunzmann/timew-gnome-indicator) | niccokunzmann | JS | GNOME shell indicator for active tracking |
| [timew-xfce-genmon](https://github.com/crossbone-magister/timewarrior-extensions) | crossbone-magister | Shell | XFCE4 panel widget |
| [timew-csv](https://github.com/crossbone-magister/timewarrior-extensions) | crossbone-magister | Shell | CSV export extension |
| [timew-histogram](https://github.com/crossbone-magister/timewarrior-extensions) | crossbone-magister | Python | Time histogram plots |

## Integration Priority for ww

1. **timew-sync** (server + client) — enables multi-device time sync, pairs with TaskChampion sync
2. **pomodoro-warriors** — focused work technique, natural fit for ww workflow
3. **timew-billable** — invoicing from time data, connects time to ledger
4. **timewarrior-aggregate** — time budgeting, connects to schedule service

## Notes

- TimeWarrior extensions are typically Python scripts placed in `~/.timewarrior/extensions/`
- For ww, extensions should be profile-scoped: `profiles/<name>/.timewarrior/extensions/`
- The `ww extensions timewarrior` command should manage these per-profile
