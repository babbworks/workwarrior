# cherusk/tw_projector

**URL:** https://github.com/cherusk/tw_projector  
**Stars:** 1  
**Language:** Python  
**Last push:** 2019-04-21  
**Archived:** No  
**Topics:** convenience, feasibility, prediction, projection, taskwarrior, taskwarrior2  

## Description

Taskwarrior based doability projector and reviser

## Category

NLP / AI

## Workwarrior Integration Rating

**Score:** 0  
**Rating:** ★★☆☆☆  Low  

### Scoring notes

- (no matching signals)

## README excerpt

```

## Taskwarrior projector
---

### Gist

Taskwarrior offers many facilities to keep a structured overview even when
faced with a myriad of tasks. Yet, the real world can be complex and is full of
constraints, like priorities and conflicting task sizing proportions for
existing spare scheduling slots. To alleviate for the human operator the
decision taking burden of what to work off the bulk of tasks next and to
maintain visibility on the actual feasiblity of the coming steps in mind, this
light projector mechanism was created.

### Usage Principle 

1. generate a set of default meta run specifications and selected tasks
2. alter generation to fit current prospection interests
3. run with the previously alterated specification to learn the feasiblity and
   quality of the foreseen scenarious

### Usage Example

```
From <tw_projector root directory> run
1.) 

# ./invoke.py generate -c my_scenario.yml

2.) 
# <edit> my_scenario.yml

3.) 
# ./invoke.py project -p my_scenario.yml

```

### Install

For now, simply clone this.


```