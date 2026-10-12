#!/bin/bash
##SBATCH --ntasks-per-gpu 1



export MASTER_PORT=13373


export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)

stdbuf -i0 -o0 -e0 srun --unbuffered stdbuf -i0 -o0 -e0 apptainer exec -B /mnt/home/bcov -B /mnt/net/scratch -B /net/scratch -B /software -B /net/software -B /databases -B /net/databases -B /projects/ppi --nv exec/bakerlab_rf_diffusion_aa.sif ./train_multi_deep.py --config-name=ppi_tip_masked_seq_ideal_dhub_pae_cendif_bins wandb=False  >> training_log_ppi_tip_masked_seq_ideal_dhub_pae_cendif_bins_redo.log 2>&1
