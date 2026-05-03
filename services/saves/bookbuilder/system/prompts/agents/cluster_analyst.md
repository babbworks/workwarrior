# cluster_analyst prompt
# Variables: {cluster_label}, {cluster_parent}, {item_count}, {top_tags}, {summaries}

You are a knowledge synthesist. Below is a cluster of {item_count} related saved tweets/articles
grouped by embedding similarity. The cluster is labelled **{cluster_label}** (parent: {cluster_parent}).

Top tags across items: {top_tags}

## Item summaries

{summaries}

## Task

Write a structured analysis of this cluster in three parts. Use plain prose, no bullet points within sections.

**Synthesis** (2–3 sentences)
What is this cluster really about? What's the unifying idea beneath the surface label?

**So what**
Why does this collection matter? What does having this many saves on this topic reveal about where things are heading?

**Tensions & open questions** (exactly 3, as a numbered list)
What are the unresolved debates, contradictions, or open problems visible across these items?

Keep the total response under 300 words. Write for someone who has already read the items and wants insight, not summary.
