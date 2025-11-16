#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Dec  6 17:40:18 2023

@author: tijl
"""

import os
import pandas as pd
import numpy as np
import math
import matplotlib.pyplot as plt
from tqdm import tqdm
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression,Ridge,LinearRegression
from sklearn.model_selection import GroupKFold,LeaveOneGroupOut
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.svm import LinearSVR,LinearSVC

import mne
from mne.decoding import (
    SlidingEstimator,
    GeneralizingEstimator,
    Scaler,
    cross_val_multiscore,
    LinearModel,
    get_coef,
    Vectorizer,
    CSP,
)

#%%
for s in range(1,30):
    subjectnr='%02d'%s
    datapath = os.path.expanduser('/Users/22095708/Documents/PhD/Experiments/Exp1_Viewpoints/Infant')
    infn = f'{datapath}/derivatives/mne/sub-{subjectnr}_mne_epo.fif'
    behavfn = f'{datapath}/sub-{subjectnr}/eeg/sub-{subjectnr}_task-targets_events.csv'
    outfn = f'{datapath}/derivatives/results/sub-{subjectnr}_mne_results.csv'
    fig1fn = f'{datapath}/figures/mne/sub-{subjectnr}_epochs.png'
    
    if os.path.exists(infn) and os.path.exists(behavfn):
        epochs = mne.read_epochs(infn)
        
        avg = epochs.average()
        p=avg.plot_joint(show=0)
        p.savefig(fig1fn)
        
       
        X = epochs.get_data()
        T = epochs.events[:,2]-2
        Y = pd.DataFrame({'time':epochs.times})
        
        #%% decoding category
        
        # leave one rotation out
        y = [math.ceil(x/8) for x in T] #decode the object
        groups = np.array([x%8 for x in T])
        
        # leave one block out
        #y = [x for x in T['stimnumber']]#per individual stimulus 
        #groups = np.array(T['blocksequencenumber'])
        
        
        #clf = make_pipeline(LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y))))
        #clf = make_pipeline(LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y)), solver='eigen')) #with regularization
        #clf = make_pipeline(LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y)), solver='lsqr')) #with regularization
        #clf = make_pipeline(StandardScaler(), LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y)))) #with regularization
        #clf = make_pipeline(LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y)), solver= 'eigen', shrinkage=0.1)) #with regularization
        #clf = make_pipeline(StandardScaler(), LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y)), solver= 'eigen', shrinkage=0.1)) #with regularization
        #clf = make_pipeline(LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y)), solver='lsqr', shrinkage=0.1)) #with regularization

        clf = make_pipeline(LinearDiscriminantAnalysis(priors=(1+0*np.unique(y))/len(np.unique(y))))
        time_decod = SlidingEstimator(clf, n_jobs=-1, scoring="balanced_accuracy", verbose=0)
        scores = cross_val_multiscore(time_decod, X, y, groups=groups, cv=LeaveOneGroupOut(), n_jobs=-1)
        
        # Mean scores across cross-validation splits
        Y['object_decoding'] = np.mean(scores, axis=0)
        
        #%% Plot
        fig, ax = plt.subplots()
        ax.plot(epochs.times, Y['object_decoding'], label="score")
        ax.axhline(1/len(np.unique(y)), color="k", linestyle="--", label="chance")
        ax.set_xlabel("Times")
        ax.set_ylabel("Accuracy")
        ax.legend()
        ax.axvline(0.0, color="k", linestyle="-")
        ax.set_title("Object decoding")
        plt.show()
        
        
        
        fig.savefig(fig1fn.replace('_epochs','_decoding-object'))
        
        #%%
        Y.to_csv(outfn)
        