# RFdiffusion2-RP: SS/Adj Conditioning and Inference

This repository contains scripts and examples for running RFdiffusion2
with secondary-structure (SS) and adjacency (adj) conditioning.

The example demonstrates designing protein scaffolds around a
cobalt-binding motif using a fine-tuned RFdiffusion2 model.

## 1. Repository Structure

```text
RFdiffusion2-RP/
├── README.md
├── helper_scripts/
│   ├── README.md
│   ├── make_ss_adj_simple.py
│   └── output_cobalt_renumbered.pdb
├── rf_diffusion/
│   ├── aa_model.py
│   ├── run_inference.py
│   ├── conditions/
│   │   └── ss_adj/
│   │       └── sec_struct_adjacency.py
│   ├── config/
│   │   └── inference/
│   │       └── paul_0.yaml
│   └── exec/
│       ├── rf_diffusion_aa_shebang.sh
│       └── bakerlab_rf_diffusion_aa.sif
└── weights/
    ├── RFD_8.pt
    ├── RFD_9.pt
    └── RFD_10.pt
```

The Apptainer image is downloaded separately and is not included
in the GitHub repository.

Model checkpoints are stored using Git LFS.

---

## 2. Clone the Repository

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/RFdiffusion2-RP.git

cd RFdiffusion2-RP
```

Replace `YOUR_USERNAME` with your GitHub username.

If your repository uses Git submodules, initialize them:

```bash
git submodule update --init --recursive
```

Install Git LFS and download model weights:

```bash
git lfs install

git lfs pull
```

---

## 3. Configure Environment Variables

All paths are defined relative to the repository root.

Run these commands from the root of the repository:

```bash
export REPO_DIR="$PWD"

export RFDIFFUSION_DIR="$REPO_DIR/rf_diffusion"

export SIF_PATH="$RFDIFFUSION_DIR/exec/bakerlab_rf_diffusion_aa.sif"

export WEIGHTS_DIR="$REPO_DIR/weights"

export INPUT_DIR="$REPO_DIR/helper_scripts"

export DESIGN_DIR="$REPO_DIR/outputs/cobalt_ss_adj"

export PYTHONPATH="$REPO_DIR${PYTHONPATH:+:$PYTHONPATH}"
```

Create the required directories:

```bash
mkdir -p "$RFDIFFUSION_DIR/exec"

mkdir -p "$DESIGN_DIR"
```

These environment variables make the commands portable across
different computing environments.

---

## 4. Download the RFdiffusion2 Apptainer

RFdiffusion2 uses an Apptainer container containing the Python
environment and dependencies required for inference.

The official container is available from:

https://files.ipd.uw.edu/pub/rfdiffusion2/sifs/rfdiffusion.sif

### Download the container

Run the following from the repository root:

```bash
export REPO_DIR="$PWD"

export RFDIFFUSION_DIR="$REPO_DIR/rf_diffusion"

export SIF_PATH="$RFDIFFUSION_DIR/exec/bakerlab_rf_diffusion_aa.sif"

mkdir -p "$RFDIFFUSION_DIR/exec"

if [ -f "$SIF_PATH" ]; then
    echo "Apptainer already exists: $SIF_PATH"
else
    if [ -L "$SIF_PATH" ]; then
        echo "Removing broken symlink: $SIF_PATH"
        unlink "$SIF_PATH"
    fi

    curl -fL --retry 3 \
        -o "$SIF_PATH" \
        https://files.ipd.uw.edu/pub/rfdiffusion2/sifs/rfdiffusion.sif
fi
```

The downloaded container will be saved as:

```text
rf_diffusion/exec/bakerlab_rf_diffusion_aa.sif
```

**Important:** Although the remote filename is `rfdiffusion.sif`,
the `curl -o` option saves it locally as
`bakerlab_rf_diffusion_aa.sif`.

This filename is required by the repository's
`rf_diffusion_aa_shebang.sh` script.

### Verify the installation

Check that the container exists:

```bash
ls -lh "$SIF_PATH"
```

Verify the Python environment:

```bash
apptainer exec --nv "$SIF_PATH" \
    python -c "import torch, omegaconf; print('PyTorch:', torch.__version__); print('OmegaConf:', omegaconf.__version__)"
```

The command should print the installed PyTorch and OmegaConf versions.

### Compatibility with the RFdiffusion shebang

The repository includes:

```text
rf_diffusion/exec/rf_diffusion_aa_shebang.sh
```

This script automatically locates the Apptainer image using:

```bash
SCRIPT_PATH=$(realpath "$0")

SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

SIF_PATH="$SCRIPT_DIR/bakerlab_rf_diffusion_aa.sif"
```

Therefore, the container must be located at:

```text
rf_diffusion/exec/bakerlab_rf_diffusion_aa.sif
```

Once installed, Python scripts configured with the corresponding
shebang can automatically launch inside the container.

**Note:** This container should not be committed to GitHub.
Add `*.sif` to `.gitignore`.

---

## 5. Generate Secondary-Structure and Adjacency Files

RFdiffusion2 supports conditioning on secondary structure
and pairwise adjacency relationships.

This example generates SS and adjacency features from a
cobalt-binding protein motif.

### Input PDB

The input structure is:

```text
helper_scripts/output_cobalt_renumbered.pdb
```

Set the input file path:

```bash
export INPUT_PDB="$INPUT_DIR/output_cobalt_renumbered.pdb"
```

### Generate SS/Adj conditioning

Run:

```bash
apptainer exec --nv \
    --env "PYTHONPATH=$PYTHONPATH" \
    "$SIF_PATH" \
    python "$INPUT_DIR/make_ss_adj_simple.py" \
    "$INPUT_PDB" \
    --aa-model "$RFDIFFUSION_DIR/aa_model.py" \
    --sec-struct-adjacency "$RFDIFFUSION_DIR/conditions/ss_adj/sec_struct_adjacency.py" \
    --mask-protein-ligand-adj
```

The `make_ss_adj_simple.py` script generates secondary-structure
and adjacency representations from the supplied PDB.

The `--mask-protein-ligand-adj` option masks protein-ligand
adjacency information when constructing the conditioning features.

### Generated files

The expected output files are:

```text
output_cobalt_renumbered.ss
output_cobalt_renumbered.adj
```

The exact output location depends on how `make_ss_adj_simple.py`
writes its results.

For the inference example below, place the files in:

```text
helper_scripts/
├── output_cobalt_renumbered.pdb
├── output_cobalt_renumbered.ss
└── output_cobalt_renumbered.adj
```

Verify that both files exist:

```bash
ls -lh "$INPUT_DIR/output_cobalt_renumbered.ss"

ls -lh "$INPUT_DIR/output_cobalt_renumbered.adj"
```

If necessary, copy the generated files into `helper_scripts/`.

---

## 6. Configure Model Checkpoints

The example uses a fine-tuned RFdiffusion2 checkpoint.

Available model weights include:

```text
weights/
├── RFD_8.pt
├── RFD_9.pt
└── RFD_10.pt
```

Set the checkpoint path:

```bash
export RFDIFFUSION_CKPT_PATH="$WEIGHTS_DIR/RFD_8.pt"
```

The model weights are tracked using Git LFS.

Ensure that the checkpoint has been downloaded before
running inference.

---

## 7. Cobalt-Binding Protein Design Example

This example designs a protein scaffold around a cobalt-binding
motif using secondary-structure and adjacency conditioning.

### Design specifications

| Parameter | Value |
|-----------|-------|
| Model checkpoint | RFD_8.pt |
| Number of designs | 6 |
| Protein scaffold length | 120 residues |
| Diffusion timesteps | 100 |
| Amino acid decoding steps | 40 |
| Ligand | COB |
| Motif residues | C1–C6 |
| Secondary-structure conditioning | Enabled |
| Adjacency conditioning | Enabled |
| Relative SASA conditioning | Enabled |
| Radius of gyration conditioning | Enabled |
| Guidepost conditioning | Enabled |

The example uses six cobalt-coordinating residues as structural
constraints while generating the surrounding protein scaffold.

### Configure input and output paths

```bash
export INPUT_PDB="$INPUT_DIR/output_cobalt_renumbered.pdb"

export SS_PATH="$INPUT_DIR/output_cobalt_renumbered.ss"

export ADJ_PATH="$INPUT_DIR/output_cobalt_renumbered.adj"

export RFDIFFUSION_CKPT_PATH="$WEIGHTS_DIR/RFD_8.pt"

export DESIGN_DIR="$REPO_DIR/outputs/cobalt_ss_adj"

mkdir -p "$DESIGN_DIR"
```

### Run inference

```bash
apptainer exec --nv \
  --env "PYTHONPATH=$PYTHONPATH" \
  "$SIF_PATH" \
  python "$RFDIFFUSION_DIR/run_inference.py" \
  --config-name=paul_0.yaml \
  guidepost_bonds=True \
  inference.align_motif=False \
  inference.ckpt_path="$RFDIFFUSION_CKPT_PATH" \
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
```

This command uses the generated `.ss` and `.adj` files rather
than hardcoded paths to a separate working directory.

**Important:** The input PDB must contain the required motif
residues and ligand. The previous
`output_cobalt_renumbered_ca_com.pdb` file contained only an
`ORI` pseudoatom and cannot be used as the complete structural
input for this example.

---

## 8. Conditioning Features

The example uses several conditioning features to control
the generated protein structure.

### Secondary-Structure and Adjacency Conditioning

The following inference configuration loads the generated
SS and adjacency files:

```bash
scaffoldguided.target_ss="$SS_PATH"

scaffoldguided.target_adj="$ADJ_PATH"
```

The corresponding conditioning feature is enabled using:

```bash
'++extra_tXd=[radius_of_gyration_v2,relative_sasa_v2,sinusoidal_timestep_embedding,ss_adj_cond]'
```

The inference transform is:

```bash
'++upstream_inference_transforms.names=[LoadTargetSSADJTransform]'
```

### Relative Solvent-Accessible Surface Area

Relative SASA conditioning is specified using:

```bash
inference.conditions.relative_sasa.mean=0.175

inference.conditions.relative_sasa.std=0.075
```

The corresponding feature configuration is:

```bash
'++extra_tXd_params.relative_sasa_v2={prob:0.2,low:0,high:0.2,n_bins:3}'
```

### Radius of Gyration

Radius-of-gyration conditioning is specified using:

```bash
inference.conditions.radius_of_gyration.mean=12.5

inference.conditions.radius_of_gyration.std=12.5
```

The corresponding feature configuration is:

```bash
'++extra_tXd_params.radius_of_gyration_v2={prob:0.2,low:10,high:100,n_bins:9}'
```

### Sinusoidal Timestep Embedding

The timestep embedding is configured using:

```bash
'++extra_tXd_params.sinusoidal_timestep_embedding={embedding_dim:20,max_positions:10000}'
```

---

## 9. Expected Output

The generated designs will be saved under:

```text
outputs/cobalt_ss_adj/
```

The inference configuration requests six designs.

Depending on the enabled output settings, RFdiffusion may
generate:

- Designed protein structures (`.pdb`)
- Diffusion trajectories
- TRB metadata files

The output prefix is:

```text
RP-tips
```

---

## 10. Running Scripts Using the Apptainer Shebang

The repository includes a shebang wrapper that automatically
launches RFdiffusion scripts inside the Apptainer container.

The wrapper is located at:

```text
rf_diffusion/exec/rf_diffusion_aa_shebang.sh
```

For Python scripts configured with the RFdiffusion shebang,
the wrapper automatically:

1. Determines the repository directory.
2. Adds the repository to `PYTHONPATH`.
3. Locates `bakerlab_rf_diffusion_aa.sif`.
4. Launches the Python script inside Apptainer.

For example:

```bash
./rf_diffusion/run_inference.py --config-name=paul_0
```

Additional Hydra configuration parameters must be provided
for the intended design task.

Alternatively, scripts can be launched explicitly using
`apptainer exec`, as demonstrated above.

---

## 11. Troubleshooting

### Apptainer not found

If the shebang reports:

```text
ERROR: RFdiffusion Apptainer container not found
```

Confirm the image exists:

```bash
ls -lh rf_diffusion/exec/bakerlab_rf_diffusion_aa.sif
```

If missing, download it using the instructions in Section 4.

### Missing Python dependencies

If you encounter:

```text
ModuleNotFoundError: No module named 'omegaconf'
```

Confirm that your script is running inside the Apptainer container.

Test with:

```bash
apptainer exec --nv "$SIF_PATH" \
    python -c "import omegaconf; print(omegaconf.__version__)"
```

### Missing SS/Adj files

Confirm that the generated files exist:

```bash
ls -lh "$SS_PATH"

ls -lh "$ADJ_PATH"
```

The paths supplied through `scaffoldguided.target_ss` and
`scaffoldguided.target_adj` must point to the generated files.

### Empty PDB structures

If inference fails with:

```text
ValueError: Empty file.
```

Verify that the input PDB contains actual protein atom records:

```bash
grep '^ATOM' "$INPUT_PDB" | head
```

For this cobalt-binding example, ensure the input structure
contains residues C1–C6 and the expected cobalt ligand.

---

## 12. Notes

- Run inference on a GPU-enabled compute node.
- The RFdiffusion2 Apptainer image is downloaded separately.
- Model checkpoints are tracked using Git LFS.
- The SS/adj generation step must be completed before inference.
- Generated outputs and large container files should not be committed
  to GitHub.
- The example uses repository-relative paths to improve portability.
- The input structure, motif residue numbering, and ligand names must
  be consistent with the inference configuration.
