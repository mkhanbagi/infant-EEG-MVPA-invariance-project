#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sun Nov 10 12:46:57 2024

@author: 22095708
"""

import os 
import numpy as np

RDM_test = np.zeros([14,14])

nObjs = 14
nIter = 0


for i in range(0,nObjs):
    for j in range(i+1,nObjs): # Avoids computing the lower half of the matrix
        if i ==j:
            RDM_test[i,j] == 0
        else:
            RDM_test[i,j] = 1
            RDM_test[j,i] = 1
        nIter = nIter+1; # check later for the number of iterations 
    
    
    
# rename files 
datapath = os.path.expanduser('~/Documents/PhD/Thesis/Experiments/Exp1_Viewpoints/Adult/derivatives/results')

for s in range(1,21):
    oldfn = f'{datapath}/sub-{"%02i"%s}_results.csv'
    if os.path.isfile(oldfn):
        newfn = oldfn.replace('_results', '_ObjDec-results')
        os.rename(oldfn, newfn)