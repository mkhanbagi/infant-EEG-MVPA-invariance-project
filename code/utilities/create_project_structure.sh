#!/bin/bash

PROJECT_ROOT="project-root"
EXPERIMENTS=("viewpoint" "occlusion")

mkdir -p "$PROJECT_ROOT"

# Root-level docs folder
mkdir -p "$PROJECT_ROOT/docs"
touch "$PROJECT_ROOT/docs/README.md"
touch "$PROJECT_ROOT/docs/LICENSE"
touch "$PROJECT_ROOT/docs/.gitignore"

mkdir -p "$PROJECT_ROOT/shared/config"
mkdir -p "$PROJECT_ROOT/shared/tools"
mkdir -p "$PROJECT_ROOT/shared/docs"

for EXP in "${EXPERIMENTS[@]}"
do
    EXP_PATH="$PROJECT_ROOT/$EXP"

    # Create main folders (only folders here)
    mkdir -p "$EXP_PATH/code/matlab"
    mkdir -p "$EXP_PATH/code/python"
    mkdir -p "$EXP_PATH/code/r"

    mkdir -p "$EXP_PATH/data/pilot/adults"
    mkdir -p "$EXP_PATH/data/pilot/infants"
    mkdir -p "$EXP_PATH/data/sourcedata"
    mkdir -p "$EXP_PATH/data/raw/adults"
    mkdir -p "$EXP_PATH/data/raw/infants"
    mkdir -p "$EXP_PATH/data/preprocessed/adults"
    mkdir -p "$EXP_PATH/data/preprocessed/infants"

    mkdir -p "$EXP_PATH/logs"

    mkdir -p "$EXP_PATH/results/figures"
    mkdir -p "$EXP_PATH/results/stats"
    mkdir -p "$EXP_PATH/results/reports"

    mkdir -p "$EXP_PATH/stimuli_dev/raw_images"
    mkdir -p "$EXP_PATH/stimuli_dev/adjusted_images"
    mkdir -p "$EXP_PATH/stimuli_dev/scripts"

    mkdir -p "$EXP_PATH/task/scripts"
    mkdir -p "$EXP_PATH/task/stimuli"
    mkdir -p "$EXP_PATH/task/logs"

    # Docs folder with files
    mkdir -p "$EXP_PATH/docs"
    touch "$EXP_PATH/docs/README.md"
    touch "$EXP_PATH/docs/environment.yml"
    touch "$EXP_PATH/docs/requirements.txt"
    touch "$EXP_PATH/docs/.gitignore"
done

echo "✅ Clean folder structure created in '$PROJECT_ROOT' with docs folders!"


