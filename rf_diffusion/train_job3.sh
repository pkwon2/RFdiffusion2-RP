#!/bin/bash
#SBATCH -p gpu-train
#SBATCH -J datahub_init_train
#SBATCH --gres=gpu:a100:4
#SBATCH --ntasks-per-node=4
#SBATCH --time=168:00:00
#SBATCH --nodes 2
#SBATCH --mem=512g
#SBATCH -c 6

export MASTER_PORT=10395


export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)

stdbuf -i0 -o0 -e0 srun --unbuffered stdbuf -i0 -o0 -e0 apptainer exec --nv exec/bakerlab_rf_diffusion_aa.sif ./train_multi_deep.py --config-name=paul_yaml_from_brian_0 wandb=False  >> training_log_paul_yaml_from_brian_0.log 2>&1
