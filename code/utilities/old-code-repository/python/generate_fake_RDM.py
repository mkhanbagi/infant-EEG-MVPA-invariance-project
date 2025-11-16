#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Nov 25 11:21:02 2024

@author: 22095708
"""
##% I) 14*14 RDM (all objects)
import numpy as np
import matplotlib.pyplot as plt

# Generate a 14x14 matrix with random values
random_matrix = np.random.rand(112, 112)

# Plot the heatmap
fig, ax = plt.subplots(figsize=(6, 6))  # Adjust figure size for better presentation
im = ax.imshow(random_matrix, cmap="viridis", interpolation="nearest")

# Add colorbar
cbar = plt.colorbar(im, ax=ax)
cbar.set_label("Similarity Score", fontsize=12)

# Customize ticks
# ax.set_xticks(range(112))
# ax.set_yticks(range(112))
# ax.set_xticklabels(range(1, 113), fontsize=10)  # Add 1-based indexing for clarity
# ax.set_yticklabels(range(1, 113), fontsize=10)

# Add axis labels
# ax.set_xlabel("Conditions", fontsize=12)
# ax.set_ylabel("Conditions", fontsize=12)

# # Add title
# ax.set_title("Random RDM Heatmap", fontsize=14)

plt.tight_layout()
plt.show()


#%% II) 24*24 RDM (3 objects - 8 rotations) >> RANDOMLY DISTRIBUTED COLORED
import numpy as np
import matplotlib.pyplot as plt

# Generate a 24x24 matrix with random values
random_matrix = np.random.rand(16, 16)

# Plot the heatmap
fig, ax = plt.subplots(figsize=(8, 8))  # Adjust figure size for better presentation
im = ax.imshow(random_matrix, cmap="viridis", interpolation="nearest")

# Add colorbar
cbar = plt.colorbar(im, ax=ax)
cbar.set_label("Similarity Score", fontsize=12)

# Customize ticks
ax.set_xticks(range(0, 16, 2))  # Display every 2nd tick to avoid clutter
ax.set_yticks(range(0, 16, 2))
ax.set_xticklabels(range(1, 17, 2), fontsize=10)  # Add 1-based indexing
ax.set_yticklabels(range(1, 17, 2), fontsize=10)

# Add axis labels
ax.set_xlabel("Conditions", fontsize=12)
ax.set_ylabel("Conditions", fontsize=12)

# Add title
ax.set_title("Random RDM Heatmap (24x24)", fontsize=14)

plt.tight_layout()
plt.show()

#%% III) 24*24 RDM ( 3 objects - 8 rotations) >> OBJECTS CLUSTERING TOGETHER 

import numpy as np
import matplotlib.pyplot as plt

# Parameters
n_objects = 2    # Number of objects (classes)
n_exemplars = 8  # Number of exemplars per object
matrix_size = n_objects * n_exemplars

# Initialize the RDM with random values
rdm = np.random.rand(matrix_size, matrix_size)

# Add clustering: smaller values within the same object, larger between objects
for obj in range(n_objects):
    start = obj * n_exemplars
    end = start + n_exemplars
    rdm[start:end, start:end] = np.random.uniform(0, 0.4, size=(n_exemplars, n_exemplars))  # Low dissimilarity within-class

# Add high dissimilarity between objects
rdm += np.random.uniform(0.6, 1.0, size=(matrix_size, matrix_size)) * (1 - np.eye(matrix_size))

# Symmetrize the matrix (RDMs are typically symmetric)
rdm = (rdm + rdm.T) / 2

# Plot the heatmap
fig, ax = plt.subplots(figsize=(10, 10))
im = ax.imshow(rdm, cmap="viridis", interpolation="nearest")

# Add colorbar
cbar = plt.colorbar(im, ax=ax)
cbar.set_label("Dissimilarity", fontsize=12)

# Customize ticks for objects and exemplars
ticks = [n_exemplars * i + n_exemplars / 2 - 0.5 for i in range(n_objects)]
tick_labels = [f"Object {i+1}" for i in range(n_objects)]
ax.set_xticks(ticks)
ax.set_yticks(ticks)
ax.set_xticklabels(tick_labels, fontsize=10)
ax.set_yticklabels(tick_labels, fontsize=10)

# Add grid lines to separate objects
for i in range(1, n_objects):
    ax.axhline(i * n_exemplars - 0.5, color="white", linestyle="--", linewidth=0.7)
    ax.axvline(i * n_exemplars - 0.5, color="white", linestyle="--", linewidth=0.7)

# Add title
ax.set_title("Clustered RDM Heatmap (24x24)", fontsize=14)

plt.tight_layout()
plt.show()

#%% IV) same as III but with better coloring options 

import numpy as np
import matplotlib.pyplot as plt

# Parameters
n_objects = 14    # Number of objects (classes)
matrix_size = n_objects  # No exemplars, so it's just 14x14

# Initialize the RDM
rdm = np.zeros((matrix_size, matrix_size))

# Assign distinct ranges for clusters (low, medium, high)
clusters = [
    np.random.uniform(0.0, 0.2, size=(n_objects, n_objects)),  # Low values for Object 1
    np.random.uniform(0.3, 0.6, size=(n_objects, n_objects)),  # Medium values for Object 2
    np.random.uniform(0.7, 1.0, size=(n_objects, n_objects)),  # High values for Object 3
]

# Fill the diagonal blocks with clusters


