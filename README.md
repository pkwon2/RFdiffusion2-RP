## Basic Information

This repository contains the modified All-Atom RFdiffusion implementation
used in the following preprint:

**Controlling metal-carbonate phase, form, and function through de novo protein design**

Paul S. Kwon, Xinqi Li, Le Tracy Yu, Harley Pyles, Todd H. Lewis,
Connor Weidle, Andrew J. Borst, Catherine C. Bodinger, Alex Kang,
Hannah Nguyen, Johnny Mendoza, Kenneth D. Carr, Brian Coventry,
Yang Hsia, Zsombor Molnar, Dongsheng Li, Bo Zhang,
Brandi M. Cossairt, Shuai Zhang, Asim K. Bera,
James De Yoreo, and David Baker.

**bioRxiv** (2026).

[Read the preprint](https://doi.org/10.64898/2026.06.10.730916)

### Citation

If you use this code in your research, please cite:

```bibtex
@article{kwon2026controlling,
  title={Controlling metal-carbonate phase, form, and function through de novo protein design},
  author={Kwon, Paul S and Li, Xinqi and Yu, Le Tracy and Pyles, Harley
    and Lewis, Todd H and Weidle, Connor and Borst, Andrew J
    and Bodinger, Catherine C and Kang, Alex and Nguyen, Hannah
    and Mendoza, Johnny and Carr, Kenneth D and Coventry, Brian
    and Hsia, Yang and Molnar, Zsombor and Li, Dongsheng
    and Zhang, Bo and Cossairt, Brandi M and Zhang, Shuai
    and Bera, Asim K and De Yoreo, James and Baker, David},
  journal={bioRxiv},
  year={2026},
  doi={10.64898/2026.06.10.730916},
  publisher={Cold Spring Harbor Laboratory}
}
```

# RFdiffusion2-RP: SS/Adj Conditioning and Inference

This repository provides an example of generating secondary-structure (SS) and adjacency (adj) conditioning features for RFdiffusion2.

The examples demonstrate protein scaffold design around cobalt-binding motifs using a fine-tuned RFdiffusion2 checkpoint. Section 7 uses precomputed secondary-structure and adjacency conditioning; Section 8 illustrates randomly sprinkled secondary-structure conditioning without external adjacency inputs.

## 1. Repository Structure

```text
RFdiffusion2-RP/
├── README.md
├── helper_scripts/
│   ├── README.md
│   ├── make_ss_adj_simple.py
│   └── inputs/
│       ├── output_cobalt_renumbered.pdb
│       ├── output_cobalt_renumbered_tips.pdb
│       ├── output_cobalt_renumbered.ss
│       ├── output_cobalt_renumbered.adj
│       └── 110_tips_2_ca_plane_ori_linesremoved_chunked_noORI_cleaned_ORI_40.pdb
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

If your environment requires the extra Python dependency directory used during setup, prepend it:

```bash
export PYTHONPATH="$HOME/.local/rfdiffusion2-python:$REPO_DIR${PYTHONPATH:+:$PYTHONPATH}"
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

The PDB used to generate the fixed SS/adjacency features is located at:

```text
helper_scripts/inputs/output_cobalt_renumbered.pdb
```

Set its path:

```bash
export INPUT_PDB="$INPUT_DIR/output_cobalt_renumbered.pdb"
```

The separate inference PDB for the four-residue tip motif is
`helper_scripts/inputs/output_cobalt_renumbered_tips.pdb`.
The second inference example below uses a different PDB and randomly generated secondary-structure conditioning.

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
    ├── output_cobalt_renumbered_tips.pdb
    ├── output_cobalt_renumbered.ss
    ├── output_cobalt_renumbered.adj
    └── 110_tips_2_ca_plane_ori_linesremoved_chunked_noORI_cleaned_ORI_40.pdb
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
| Designed scaffold length | 100 residues (plus 4 fixed motif residues) |
| Diffusion timesteps | 100 |
| Amino acid decoding steps | 40 |
| Ligand | `COB` |
| Motif residues | C1–C4 |
| SS conditioning | Enabled |
| Adjacency conditioning | Enabled |
| Relative SASA conditioning | Enabled |
| Radius-of-gyration conditioning | Enabled |
| Guidepost conditioning | Enabled |

### Configure input and output paths

```bash
export INPUT_PDB="$INPUT_DIR/output_cobalt_renumbered_tips.pdb"

export SS_PATH="$INPUT_DIR/output_cobalt_renumbered.ss"
export ADJ_PATH="$INPUT_DIR/output_cobalt_renumbered.adj"

export RFDIFFUSION_CKPT_PATH="$WEIGHTS_DIR/RFD_8.pt"

export DESIGN_DIR="$REPO_DIR/outputs/cobalt_ss_adj"

mkdir -p "$DESIGN_DIR"
```

### Contig length and motif residues

The SS/adjacency features describe **104 protein residues**. Four coordinating residues—`C1`, `C2`, `C3`, and `C4`—are explicitly included in the contig, and **each counts as one protein residue**. To keep the combined protein length at 104, the designable segment is `100-100`:

```text
100 newly designed residues + 4 motif-tip residues (C1–C4) = 104 protein residues
```

Therefore, use `contigmap.contigs=["100-100,C1,C2,C3,C4"]`, **not** `104-104,C1,C2,C3,C4`. The SS/adjacency arrays generated in Section 5 also include 84 small-molecule positions (188 positions total); those positions are distinct from the 104 protein residues.

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
  'contigmap.contigs=["100-100,C1,C2,C3,C4"]' \
  contigmap.contig_atoms="\"{'C1':'CG,ND1,CD2,CE1,NE2','C2':'CG,OD1,OD2','C3':'CG,ND1,CD2,CE1,NE2','C4':'CG,OD1,OD2'}\"" \
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

The `scaffoldguided.target_ss` and `scaffoldguided.target_adj` parameters use the files generated in Section 5. Unlike SS/adj generation, inference uses `output_cobalt_renumbered_tips.pdb` so that `C1`–`C4` correspond to actual motif residues in the PDB.

**Important:** The input PDB must contain the motif residues referenced by the contig specification and any required ligand atoms. The earlier `output_cobalt_renumbered_ca_com.pdb` contained only an `ORI` pseudoatom and is not used here.

---

## 8. Random Secondary-Structure Conditioning (No Block-Adjacency Input)

This second example designs a cobalt-associated scaffold around four glutamate (`GLU`) tip residues using **randomly sprinkled secondary-structure conditioning**. It differs from Section 7: `SSSprinkleTransform` generates the SS pattern during inference, so the command does **not** load the precomputed `.ss` or `.adj` files and does not specify `scaffoldguided.target_ss`, `scaffoldguided.target_adj`, or `LoadTargetSSADJTransform`.

The `HELIX` background and `min_mask`, `max_mask`, and `spread_efficiency` settings are preserved from the original example. This command assumes that `paul_0.yaml` already registers `SSSprinkleTransform` in the upstream inference transforms; `active=True` activates its configured transform. Check the YAML if Hydra reports an unknown key or the transform does not run.

### Input PDB and output prefix

The example uses this input structure from the cloned repository:

```text
helper_scripts/inputs/110_tips_2_ca_plane_ori_linesremoved_chunked_noORI_cleaned_ORI_40.pdb
```

The corresponding path on the original cluster checkout is:

```text
/home/pkwon2/github/RFdiffusion2-RP/helper_scripts/inputs/110_tips_2_ca_plane_ori_linesremoved_chunked_noORI_cleaned_ORI_40.pdb
```

Set the paths from the repository root:

```bash
export RANDOM_SS_INPUT_PDB="$INPUT_DIR/110_tips_2_ca_plane_ori_linesremoved_chunked_noORI_cleaned_ORI_40.pdb"
export RANDOM_SS_OUTPUT_PREFIX="$DESIGN_DIR/110_tips_2_ca_plane_ori_linesremoved_chunked_noORI_cleaned_ORI_40_8"

mkdir -p "$DESIGN_DIR"
ls -lh "$RANDOM_SS_INPUT_PDB"
```

The input PDB should be committed alongside this README so that others can run the example after cloning. The path is specific to the user's cluster, but the inference command uses repository-relative environment variables.

No `.ss` or `.adj` file needs to be supplied for **this** example. The fixed SS/adj example in Section 7 still requires its conditioning files.

### Run inference with randomly sprinkled SS

The command below preserves the original 60–80 length settings, four glutamate coordinating residues, 3 designs, and the supplied inference options, but uses environment variables and `apptainer exec` so it runs from the cloned repository:

```bash
apptainer exec --nv \
  --env "PYTHONPATH=$PYTHONPATH" \
  "$SIF_PATH" \
  python "$RFDIFFUSION_DIR/run_inference.py" \
  --config-name=paul_0.yaml \
  guidepost_bonds=True \
  inference.align_motif=False \
  inference.ckpt_path="$RFDIFFUSION_CKPT_PATH" \
  inference.num_designs=3 \
  inference.output_prefix="$RANDOM_SS_OUTPUT_PREFIX" \
  inference.input_pdb="$RANDOM_SS_INPUT_PDB" \
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
  inference.write_trajectory=False \
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
  'contigmap.contigs=["60-80,A1,B2,C3,D4"]' \
  'contigmap.length="60-80"' \
  contigmap.contig_atoms="\"{'A1':'OE1,OE2,CD,CG','B2':'OE1,OE2,CD,CG','C3':'OE1,OE2,CD,CG','D4':'OE1,OE2,CD,CG'}\"" \
  upstream_inference_transforms.configs.SSSprinkleTransform.active=True \
  upstream_inference_transforms.configs.SSSprinkleTransform.background=HELIX \
  upstream_inference_transforms.configs.SSSprinkleTransform.min_mask=2 \
  upstream_inference_transforms.configs.SSSprinkleTransform.max_mask=4 \
  upstream_inference_transforms.configs.SSSprinkleTransform.spread_efficiency=0.7
```

The four motif residues are PDB residues `A1`, `B2`, `C3`, and `D4` (one glutamate each). Their explicitly referenced side-chain atoms are `OE1`, `OE2`, `CD`, and `CG`.

**Conditioning distinction:** Section 7 uses externally generated secondary-structure **and** adjacency inputs, whereas this example uses `SSSprinkleTransform` to generate randomized secondary-structure conditioning without supplying `.ss` or `.adj` input files. These CLI overrides do not, by themselves, disable any additional conditioning hard-coded into `paul_0.yaml`; inspect that configuration if you need to guarantee no other adjacency-related transform is active.

---

## 9. Conditioning Features

The fixed SS/adjacency example in Section 7 combines several conditioning features.

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

## 10. Expected Outputs

The generated designs will be saved under:

```text
outputs/cobalt_ss_adj/
```

The fixed SS/adjacency example (Section 7) generates six designs with the prefix:

```text
RP-tips
```

The random-SS example (Section 8) generates three designs using the prefix:

```text
110_tips_2_ca_plane_ori_linesremoved_chunked_noORI_cleaned_ORI_40_8
```

Depending on the output configuration, files may include:

- Designed protein structures (`.pdb`)
- Diffusion trajectories for runs that set `inference.write_trajectory=True`
- TRB metadata (`.trb`)

---

## 11. Running Scripts Using the Apptainer Shebang

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

This minimal command is illustrative; the examples in Sections 7 and 8 require their respective inference parameters.

Alternatively, scripts can be launched explicitly using `apptainer exec`.

---

## 12. Animating diffusion trajectories

This can be pretty simple. You'll need a PDB of the final design (can have designed sidechains or not) and a PDB of the diffusion trajectory (use the *_Xt-1_traj.pdb file). Load both into PyMol and make sure the structures are aligned.

Next, you'll need to tell PyMol how to turn trajectory “states” into movie “frames”. The following command assumes you have a traj file with 200 states. It assigns the 200th state as the first movie frame and then maps all states in reverse order until it places the first state onto frame 200. We do this because traj timecourses are backward. The “1×90” bit adds 90 additional frames of state 1 to the end of the movie, allowing the viewer to see the final structure for 3 seconds. (PyMol movies are 30 frames per second by default.)

PyMOL> mset 100 -1 1x90
To make the trajectory look good, hide cartoon and instead show spheres. To make it look even better:

PyMOL> set sphere_scale,0.5
To save that movie, just File → Save Movie As → Quicktime

Convert your saved video (.mov, .mp4, etc) into a GIF for free at https://ezgif.com/video-to-gif (and compress your GIF there too!)

You can make much better animations using scenes in PyMol. For example, you probably want to keep the final design hidden until the diffusion trajectory has converged. You can do this by creating scene 01 where the trajectory is visible but the design isn't, and scene 02 where both are visible. Then you can assign scene 01 to frame 1 and scene 02 to frame 200. Scenes also store camera movement, allowing you to spin/rotate/flip or zoom during your movie. Learn how to do all this and more at https://www.pymolwiki.org/index.php/MovieSchool
