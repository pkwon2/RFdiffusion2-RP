Cobalt-binding protein design with SS/adj conditioning
This example demonstrates how to generate secondary-structure (SS) and adjacency (adj) conditioning features from a PDB structure and use them in RFdiffusion2 to design a protein scaffold around a cobalt-binding motif.
1. Download the RFdiffusion2 Apptainer
The RFdiffusion2 environment is available as an Apptainer container.
From the repository root:
cd /projects/ml/pkwon2/rf_diffusion_repo

export REPO_DIR="$PWD"
export RFDIFFUSION_DIR="$REPO_DIR/rf_diffusion"
export SIF_PATH="$RFDIFFUSION_DIR/exec/bakerlab_rf_diffusion_aa.sif"

mkdir -p "$RFDIFFUSION_DIR/exec"

curl -fL --retry 3 \
    -o "$SIF_PATH" \
    https://files.ipd.uw.edu/pub/rfdiffusion2/sifs/rfdiffusion.sif

If bakerlab_rf_diffusion_aa.sif is already a symlink, remove the symlink before downloading to avoid overwriting its target.
The downloaded Apptainer contains the Python environment required to run RFdiffusion2.
2. Generate secondary-structure and adjacency files
The script make_ss_adj_simple.py generates SS and adjacency conditioning features from an input PDB structure.
For this example, the input PDB is:
helper_scripts/output_cobalt_renumbered.pdb

First, configure the environment:
export PYTHONPATH="$REPO_DIR:${PYTHONPATH:-}"
export INPUT_PDB="$REPO_DIR/helper_scripts/output_cobalt_renumbered.pdb"

Generate the conditioning files:
apptainer exec --nv "$SIF_PATH" \
    python "$REPO_DIR/helper_scripts/make_ss_adj_simple.py" \
    "$INPUT_PDB" \
    --aa-model "$RFDIFFUSION_DIR/aa_model.py" \
    --sec-struct-adjacency "$RFDIFFUSION_DIR/conditions/ss_adj/sec_struct_adjacency.py" \
    --mask-protein-ligand-adj

This assumes make_ss_adj_simple.py is located in helper_scripts/. Adjust its path if necessary.
The --mask-protein-ligand-adj flag masks protein–ligand adjacency relationships during conditioning-file generation.
The expected outputs are:
helper_scripts/
├── output_cobalt_renumbered.pdb
├── output_cobalt_renumbered.ss
└── output_cobalt_renumbered.adj

The exact output directory depends on the implementation of make_ss_adj_simple.py.
Verify the generated files:
ls -lh "$REPO_DIR/helper_scripts/output_cobalt_renumbered."{ss,adj}

If the script writes them elsewhere, copy them to the paths above before continuing.
3. Run RFdiffusion inference
The following example uses the generated SS and adjacency files to design a 120-residue protein scaffold around six cobalt-coordinating residues.
Model checkpoint: RFD_8.pt
Diffusion steps: 100
Number of designs: 6
Ligand: COB
Conditioning: SS/adj, relative SASA, radius of gyration
Configure paths:
export CKPT_PATH="$REPO_DIR/weights/RFD_8.pt"
export INPUT_PDB="$REPO_DIR/helper_scripts/output_cobalt_renumbered.pdb"
export SS_PATH="$REPO_DIR/helper_scripts/output_cobalt_renumbered.ss"
export ADJ_PATH="$REPO_DIR/helper_scripts/output_cobalt_renumbered.adj"

export DESIGN_DIR="$REPO_DIR/outputs/cobalt_ss_adj"
mkdir -p "$DESIGN_DIR"

Run inference:
apptainer exec --nv \
  --env "PYTHONPATH=$PYTHONPATH" \
  "$SIF_PATH" \
  python "$RFDIFFUSION_DIR/run_inference.py" \
  --config-name=paul_0.yaml \
  guidepost_bonds=True \
  inference.align_motif=False \
  inference.ckpt_path="$CKPT_PATH" \
  inference.num_designs=6 \
  inference.output_prefix="$DESIGN_DIR/RP-tips" \
  inference.input_pdb="$INPUT_PDB" \
  inference.final_step=1 \
  inference.contig_as_guidepost=True \
  inference.remove_guideposts_from_output=True \
  inference.infer_guidepost_positions=True \
  inference.guidepost_xyz_as_design=True \
  inference.flexible_ligand=False \
  inference.ligand=COB \
  inference.state_dict_to_load=model_state_dict \
  inference.deterministic=False \
  inference.idealize_sidechain_outputs=True \
  inference.radius=10.0 \
  inference.write_trajectory=True \
  inference.write_trb=True \
  inference.write_trb_indep=False \
  inference.write_trb_trajectory=False \
  inference.center_motif=True \
  inference.recenter_xt=False \
  inference.update_seq_t=False \
  inference.conditions.relative_sasa.mean=0.175 \
  inference.conditions.relative_sasa.std=0.075 \
  inference.conditions.radius_of_gyration.mean=12.5 \
  inference.conditions.radius_of_gyration.std=12.5 \
  diffuser.T=100 \
  diffuser.aa_decode_steps=40 \
  'contigmap.contigs=["120-120,C1,C2,C3,C4,C5,C6"]' \
  'contigmap.contig_atoms="{'"'"'C1'"'"':'"'"'CG,ND1,CD2,CE1,NE2'"'"','"'"'C2'"'"':'"'"'CG,OD1,OD2'"'"','"'"'C3'"'"':'"'"'CG,ND1,CD2,CE1,NE2'"'"','"'"'C4'"'"':'"'"'CG,OD1,OD2'"'"','"'"'C5'"'"':'"'"'CG,ND1,CD2,CE1,NE2'"'"','"'"'C6'"'"':'"'"'CG,OD1,OD2'"'"'}"' \
  'contigmap.has_termini=[True]' \
  scaffoldguided.target_ss="$SS_PATH" \
  scaffoldguided.target_adj="$ADJ_PATH" \
  '++extra_tXd=[radius_of_gyration_v2,relative_sasa_v2,sinusoidal_timestep_embedding,ss_adj_cond]' \
  '++extra_tXd_params.radius_of_gyration_v2={prob:0.2,low:10,high:100,n_bins:9}' \
  '++extra_tXd_params.relative_sasa_v2={prob:0.2,low:0,high:0.2,n_bins:3}' \
  '++extra_tXd_params.sinusoidal_timestep_embedding={embedding_dim:20,max_positions:10000}' \
  '++extra_tXd_params.ss_adj_cond={}' \
  '++upstream_inference_transforms.names=[LoadTargetSSADJTransform]' \
  '++upstream_inference_transforms.configs.LoadTargetSSADJTransform={}' \
  '++upstream_training_transforms.names=[GenerateSSADJTrainingTransform]' \
  '++upstream_training_transforms.configs.GenerateSSADJTrainingTransform={p_is_ss_example:1,p_is_adj_example:1}'

The inference command preserves the conditioning parameters from the original example.
Important: This version uses output_cobalt_renumbered.pdb for inference, rather than the earlier output_cobalt_renumbered_ca_com.pdb. The latter contained only an ORI pseudoatom and caused an empty-structure parsing error. Confirm that the original PDB contains motif residues C1–C6 and the COB ligand before running.
4. Expected outputs
RFdiffusion generates six designs under:
outputs/cobalt_ss_adj/

The output files may include PDB structures, diffusion trajectories, and .trb metadata files, depending on the configuration.
5. Model checkpoints
The example uses the epoch-8 checkpoint:
weights/RFD_8.pt

Other available checkpoints include:
weights/RFD_9.pt
weights/RFD_10.pt

These checkpoints are stored using Git LFS.