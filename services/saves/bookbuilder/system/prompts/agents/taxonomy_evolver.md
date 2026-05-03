# taxonomy_evolver prompt
# Variables: {uncategorized_count}, {noise_count}, {top_tags},
#            {uncategorized_samples}, {noise_samples}, {existing_categories}

You are a knowledge taxonomy designer. A personal knowledge base has {uncategorized_count} uncategorized
items and {noise_count} items in the noise cluster that don't fit the current taxonomy.

## Existing top-level categories

{existing_categories}

## Top tags across flagged items

{top_tags}

## Uncategorized item samples

{uncategorized_samples}

## Noise cluster samples

{noise_samples}

## Task

Propose new taxonomy subcategories that would capture these items.

For each proposal, write:

**`parent_category/new_subcategory_key`**
Label: Short human-readable label
Description: One sentence.
Would capture: 2–3 example items from the samples above.
Keywords: 5–8 seed keywords for the AI classifier.

Rules:
- Propose subcategories under existing parent categories where possible
- Only propose a new top-level category if nothing existing fits
- Use snake_case keys
- Be specific — "llm_evals" is better than "ai_research_misc"
- Aim for 3–6 proposals total, not an exhaustive list

End with a short paragraph on whether the uncategorized items represent a genuine gap
in the taxonomy or just low-quality saves that should stay uncategorized.
