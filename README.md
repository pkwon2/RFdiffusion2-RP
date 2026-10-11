# RFdiffusion2-RP: SS/Adj Conditioning and Inference

This repository provides an example of generating secondary-structure (SS) and adjacency (adj) conditioning features for RFdiffusion2.

The example demonstrates protein scaffold design around a cobalt-binding motif using a fine-tuned RFdiffusion2 checkpoint.

## 1. Repository Structure

```text
RFdiffusion2-RP/
├── README.md
├── helper_scripts/
│   ├── README.md
│   ├── make_ss_adj_simple.py
│   └── inputs/
│       └── output_cobalt_renumbered.pdb
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
├── weights/
│   ├── RFD_8.pt
│   ├── RFD_9.pt
│   └── RFD_10.pt
└── outputs/
    └── cobalt_ss_adj/
```

The Apptainer image is downloaded separately and is not included in the GitHub repository. Model checkpoints are stored using Git LFS.

The `outputs/` directory is created during inference.

---

## 2. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/RFdiffusion2-RP.git
cd RFdiffusion2-RP
```

Replace `YOUR_USERNAME` with your GitHub username.

If the repository uses Git submodules:

```bash
git submodule update --init --recursive
```

Download model checkpoints tracked by Git LFS:

```bash
git lfs install
git lfs pull
```

---

## 3. Configure Environment Variables

Run these commands from the root of the repository:

```bash
export REPO_DIR="$PWD"
export RFDIFFUSION_DIR="$REPO_DIR/rf_diffusion"
export SIF_PATH="$RFDIFFUSION_DIR/exec/bakerlab_rf_diffusion_aa.sif"

export WEIGHTS_DIR="$REPO_DIR/weights"
export INPUT_DIR="$REPO_DIR/helper_scripts/inputs"
export DESIGN_DIR="$REPO_DIR/outputs/cobalt_ss_adj"

export PYTHONPATH="$REPO_DIR${PYTHONPATH:+:$PYTHONPATH}"
```

Create the required directories:

```bash
mkdir -p "$RFDIFFUSION_DIR/exec"
mkdir -p "$DESIGN_DIR"
```

These variables allow the example to run regardless of where the repository is cloned.

---

## 4. Download the RFdiffusion2 Apptainer

RFdiffusion2 uses an Apptainer container to provide the Python environment and dependencies required for inference.

The container is available at:

https://files.ipd.uw.edu/pub/rfdiffusion2/sifs/rfdiffusion.sif

### Download the container

From the repository root:

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

Although the remote filename is `rfdiffusion.sif`, the `curl -o` argument saves it locally as:

```text
rf_diffusion/exec/bakerlab_rf_diffusion_aa.sif
```

This matches the filename expected by the RFdiffusion shebang script.

### Make the container and shebang executable

```bash
chmod +x "$SIF_PATH"
chmod +x "$RFDIFFUSION_DIR/exec/rf_diffusion_aa_shebang.sh"
```

The executable permission on the SIF is optional when launching it through `apptainer exec` or `apptainer run`. The shebang runner should be executable.

### Verify the installation

Check the downloaded file:

```bash
ls -lh "$SIF_PATH"
```

Test the Python environment:

```bash
apptainer exec --nv "$SIF_PATH" \
    python -c "import torch, omegaconf; print('PyTorch:', torch.__version__); print('OmegaConf:', omegaconf.__version__)"
```

### Compatibility with the RFdiffusion shebang

The repository includes:

```text
rf_diffusion/exec/rf_diffusion_aa_shebang.sh
```

The script locates the container using:

```bash
SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

SIF_PATH="$SCRIPT_DIR/bakerlab_rf_diffusion_aa.sif"
```

Therefore, the downloaded container must be located at:

```text
rf_diffusion/exec/bakerlab_rf_diffusion_aa.sif
```

Scripts configured with the RFdiffusion shebang can automatically run inside this container.

**Note:** The container should not be committed to GitHub. Add `*.sif` to `.gitignore`.

---

## 5. Generate Secondary-Structure and Adjacency Files

RFdiffusion2 supports conditioning on secondary structure and pairwise adjacency relationships.

This example generates SS and adjacency features from a cobalt-binding protein motif.

### Input PDB

The example PDB is located at:

```text
helper_scripts/inputs/output_cobalt_renumbered.pdb
```

Set its path:

```bash
export INPUT_PDB="$INPUT_DIR/output_cobalt_renumbered.pdb"
```

### Generate SS/Adj conditioning

Run:

```bash
apptainer exec --nv \
    --env "PYTHONPATH=$PYTHONPATH" \
    "$SIF_PATH" \
    python "$REPO_DIR/helper_scripts/make_ss_adj_simple.py" \
    "$INPUT_PDB" \
    --aa-model "$RFDIFFUSION_DIR/aa_model.py" \
    --sec-struct-adjacency "$RFDIFFUSION_DIR/conditions/ss_adj/sec_struct_adjacency.py" \
    --mask-protein-ligand-adj
```

The `make_ss_adj_simple.py` script generates secondary-structure and adjacency conditioning features from the input PDB.

The `--mask-protein-ligand-adj` flag masks protein–ligand adjacency information when generating the adjacency representation.

### Generated files

The expected files are:

```text
output_cobalt_renumbered.ss
output_cobalt_renumbered.adj
```

For this example, the files should be available at:

```text
helper_scripts/
├── make_ss_adj_simple.py
└── inputs/
    ├── output_cobalt_renumbered.pdb
    ├── output_cobalt_renumbered.ss
    └── output_cobalt_renumbered.adj
```

The exact output location depends on the implementation of `make_ss_adj_simple.py`.

If the script writes the files elsewhere, move or copy them into `helper_scripts/inputs/` before running inference.

### Verify generated files

```bash
ls -lh "$INPUT_DIR/output_cobalt_renumbered.ss"
ls -lh "$INPUT_DIR/output_cobalt_renumbered.adj"
```

Both files must exist before running inference.

---

## 6. Configure Model Checkpoints

This example uses the fine-tuned RFdiffusion2 checkpoint:

```text
weights/RFD_8.pt
```

Additional checkpoints include:

```text
weights/RFD_9.pt
weights/RFD_10.pt
```

Set the checkpoint path:

```bash
export RFDIFFUSION_CKPT_PATH="$WEIGHTS_DIR/RFD_8.pt"
```

Confirm the file exists:

```bash
ls -lh "$RFDIFFUSION_CKPT_PATH"
```

Model checkpoints are stored using Git LFS.

---

## 7. Cobalt-Binding Protein Design Example

This example generates protein scaffolds around a cobalt-binding motif using secondary-structure, adjacency, and additional structural conditioning features.

### Design specifications

| Parameter | Value |
|---|---|
| Model checkpoint | `RFD_8.pt` |
| Number of designs | 6 |
| Designed scaffold length | 120 residues |
| Diffusion timesteps | 100 |
| Amino acid decoding steps | 40 |
| Ligand | `COB` |
| Motif residues | C1–C6 |
| SS conditioning | Enabled |
| Adjacency conditioning | Enabled |
| Relative SASA conditioning | Enabled |
| Radius-of-gyration conditioning | Enabled |
| Guidepost conditioning | Enabled |

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

The `scaffoldguided.target_ss` and `scaffoldguided.target_adj` parameters use the files generated in Section 5.

**Important:** The input PDB must contain the motif residues referenced by the contig specification and any required ligand atoms. The earlier `output_cobalt_renumbered_ca_com.pdb` contained only an `ORI` pseudoatom and is not used here.

---

## 8. Conditioning Features

The example combines several conditioning features.

### Secondary structure and adjacency

Secondary-structure and adjacency conditioning is enabled through:

```bash
scaffoldguided.target_ss="$SS_PATH"
scaffoldguided.target_adj="$ADJ_PATH"
```

The `ss_adj_cond` feature and `LoadTargetSSADJTransform` load these features during inference.

### Relative SASA

```bash
inference.conditions.relative_sasa.mean=0.175
inference.conditions.relative_sasa.std=0.075
```

Feature configuration:

```bash
'++extra_tXd_params.relative_sasa_v2={prob:0.2,low:0,high:0.2,n_bins:3}'
```

### Radius of gyration

```bash
inference.conditions.radius_of_gyration.mean=12.5
inference.conditions.radius_of_gyration.std=12.5
```

Feature configuration:

```bash
'++extra_tXd_params.radius_of_gyration_v2={prob:0.2,low:10,high:100,n_bins:9}'
```

### Sinusoidal timestep embedding

```bash
'++extra_tXd_params.sinusoidal_timestep_embedding={embedding_dim:20,max_positions:10000}'
```

---

## 9. Expected Outputs

The generated designs will be saved under:

```text
outputs/cobalt_ss_adj/
```

The example generates six designs with the prefix:

```text
RP-tips
```

Depending on the output configuration, files may include:

- Designed protein structures (`.pdb`)
- Diffusion trajectories
- TRB metadata (`.trb`)

---

## 10. Running Scripts Using the Apptainer Shebang

The repository includes:

```text
rf_diffusion/exec/rf_diffusion_aa_shebang.sh
```

This script automatically:

1. Determines the repository directory.
2. Adds the repository to `PYTHONPATH`.
3. Locates `bakerlab_rf_diffusion_aa.sif`.
4. Launches the script inside Apptainer.

Make sure the shebang runner is executable:

```bash
chmod +x "$RFDIFFUSION_DIR/exec/rf_diffusion_aa_shebang.sh"
```

Scripts configured with the appropriate shebang can be executed directly:

```bash
./rf_diffusion/run_inference.py --config-name=paul_0
```

This minimal command is illustrative; the cobalt-binding example requires the additional inference parameters provided in Section 7.

Alternatively, scripts can be launched explicitly using `apptainer exec`.

---

## 11. Troubleshooting

### Apptainer not found

If you encounter:

```text
ERROR: RFdiffusion Apptainer container not found
```

Check:

```bash
ls -lh "$SIF_PATH"
```

Download the container using Section 4 if it is missing.

### Missing Python dependencies

If you encounter:

```text
ModuleNotFoundError: No module named 'omegaconf'
```

Verify that the script is running inside the container:

```bash
apptainer exec --nv "$SIF_PATH" \
    python -c "import omegaconf; print(omegaconf.__version__)"
```

### Missing SS/Adj files

Verify:

```bash
ls -lh "$SS_PATH"
ls -lh "$ADJ_PATH"
```

If they do not exist, rerun the SS/adj generation step and check where `make_ss_adj_simple.py` writes its outputs.

### Empty input structures

If inference fails with:

```text
ValueError: Empty file.
```

Check that the input PDB contains protein atom records:

```bash
grep '^ATOM' "$INPUT_PDB" | head
```

Also verify that the motif residues and ligand names match the inference configuration.

### Broken Apptainer symlink

Check whether the container path is a symlink:

```bash
ls -l "$SIF_PATH"
```

If it is broken:

```bash
unlink "$SIF_PATH"
```

Then rerun the download instructions.

---

## 12. Notes

- Run inference on a GPU-enabled compute node.
- The RFdiffusion2 Apptainer image is downloaded separately.
- Model checkpoints are tracked using Git LFS.
- Generate the SS/adj files before running inference.
- Ensure the input PDB contains the intended motif residues and ligand.
- Do not commit Apptainer images or generated inference outputs to GitHub.
- Use repository-relative paths for reproducibility.
