#!/bin/bash
#SBATCH -p cpu
#SBATCH -J mmseqs_iiab
#SBATCH --time=02:00:00
#SBATCH -c 8
#SBATCH --mem=12g
#SBATCH -o digs.log
#SBATCH -e digs.log

/software/mmseqs2/bin/mmseqs easy-linclust /projects/ml/pkwon2/repeat_protein_data.fasta /projects/ml/pkwon2/ /tmp --min-seq-id 0.3 -c 0.8 --cov-mode 0 --threads 8
