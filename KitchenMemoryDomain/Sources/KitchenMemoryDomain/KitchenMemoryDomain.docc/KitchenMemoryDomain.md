# ``KitchenMemoryDomain``

Model the meaning and rules of a household kitchen independently of persistence,
synchronization, and user interface frameworks.

## Overview

Kitchen Memory begins with three independently persistable domain entities:

- ``Kitchen`` is the ownership and collaboration boundary.
- ``Recipe`` is the durable identity of a maintained dish.
- ``RecipeRevision`` is one intentional representation in that recipe's history.

Each entity uses an application-owned ``StableIdentifier`` so its identity can
survive export, import, persistence migrations, and synchronization changes.

The package deliberately contains no SwiftData or CloudKit types. Those
frameworks belong behind application repository and synchronization boundaries.
