# bergercookie/item_synchronizer

**URL:** https://github.com/bergercookie/item_synchronizer  
**Stars:** 12  
**Language:** Python  
**Last push:** 2023-12-31  
**Archived:** No  
**Topics:** calendar, python, synchronization, taskwarrior, todo, todoapp  

## Description

🔄 Synchronize items from two different sources

## Category

Sync

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww

## README excerpt

```
# Item Synchronizer

<img src="https://github.com/bergercookie/item_synchronizer/raw/master/res/logo.png" alt="logo" style="zoom:50%;" />

<a href="https://github.com/bergercookie/item_synchronizer/actions" alt="CI">
<img src="https://github.com/bergercookie/item_synchronizer/actions/workflows/ci.yml/badge.svg"/></a>
<a href="https://github.com/pre-commit/pre-commit">
<img src="https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white" alt="pre-commit"></a>

<a href='https://coveralls.io/github/bergercookie/item_synchronizer'>
<img src='https://coveralls.io/repos/github/bergercookie/item_synchronizer/badge.svg' alt='Coverage Status' /></a>
<a href="https://github.com/bergercookie/item_synchronizer/blob/master/LICENSE.md" alt="LICENCE">
<img src="https://img.shields.io/github/license/bergercookie/item_synchronizer.svg" /></a>
<a href="https://pypi.org/project/item_synchronizer/" alt="pypi">
<img src="https://img.shields.io/pypi/pyversions/item-synchronizer.svg" /></a>
<a href="https://badge.fury.io/py/item-synchronizer">
<img src="https://badge.fury.io/py/item-synchronizer.svg" alt="PyPI version" height="18"></a>
<a href="https://pepy.tech/project/item-synchronizer">
<img alt="Downloads" src="https://pepy.tech/badge/item-synchronizer"></a>
<a href="https://github.com/psf/black">
<img alt="Code style: black" src="https://img.shields.io/badge/code%20style-black-000000.svg"></a>

## Description

Synchronize items from two different sources in a bidirectional manner.

This library aims to offer an abstract and versatile way to _create_, _update_
and/or _delete_ items to keep two "sources" in sync.

These "items" may range from Calendar entries, TODO task lists, or whatever else
you want as long as the user registers the appropriate functions/methods to
convert from one said item to another.

## Usage

The `Synchronizer` class requires the following `Callable`s to be given, for each
one of the sides. See the most up-to-date python types
[here](https://github.com/bergercookie/item_synchronizer/blob/master/item_synchronizer/types.py)

- Insertion callable: when called with the contents of an item it should create
  and return the ID of the newly added item on the other source
- Update callable: update an item given by the item ID, using the (possibly
  partial) new contents specified by Item
- Deletion callable: Delete the item given by the specified ID
- Conversion callable: convert an item from the format of one source to the
  format of another.
- `Item Getter` callable: Given the ID of an Item of one source return the
  corresponding item on the other source.
- `A_to_B` [bidict](https://github.com/jab/bidict)

  - This should be a bidict mapping IDs of A to the corresponding IDs of B and
    vice-versa. Given this the `item_synchronizer` is responsible for keeping
    it up to date on insertion, update and deletion events. The contents of this
    bidict should be persistent across the various runs, thus, consider
 
```