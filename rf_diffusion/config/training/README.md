# Adding a New Conditioning Feature to RFdiffusion

This guide outlines how to implement a new conditioning feature for RFdiffusion training and inference. It follows the existing hotspot/anti-hotspot and secondary-structure/adjacency (SS/ADJ) implementations.

> **Scope:** These are development notes for this codebase. Example paths, model checkpoints, script locations, and cluster commands may need adjusting to your environment. `YOUR_FILE`, `MY_NEW_CONDITION`, and `WHATEVER_YOU_CALLED_YOUR_TRAINING_YAML` are placeholders.

## Implementation checklist

To add a new condition, implement the following components:

1. **Training feature function:** Compute the PyTorch tensor representing the condition.
2. **Training transform:** Insert the feature into `conditions_dict`.
3. **`ExpandConditionsDict`:** Expand the condition when guideposting or atomization adds residues.
4. **Training `extra_tXd` featurizer:** Convert `conditions_dict` entries to the model's `extra_t1d` or `extra_t2d` inputs.
5. **Training YAML:** Register the transform and featurizer, and update channel dimensions.
6. **Inference flags:** Expose any user-specified inputs in `config/inference/base.yaml` or the transform configuration.
7. **Inference transform:** Convert inference inputs into `conditions_dict`.
8. **Inference YAML:** Register the inference transform and featurizer.
9. **Reshaped weights:** Adapt the starting checkpoint if additional feature channels are needed.

## 1. Create a condition module

Unless the condition belongs in an existing module, create:

`rf_diffusion/conditions/YOUR_FILE.py`

Keep the condition-generating function, transforms, and `extra_tXd` featurizers together in this module.

## 2. Implement the training feature function

**File:** `rf_diffusion/conditions/YOUR_FILE.py`

This function computes the feature you want the model to condition on. A simple skeleton is:

```python
def calculate_my_condition(indep):
    my_feature = torch.zeros(indep.length())

    # Populate the feature for the residues of interest.

    return my_feature
```

Choose how much spatial detail to encode:

- **Exact, position-by-position features:** Give the model richer information, but may require equally detailed specification at inference time unless you introduce appropriate noise or flexibility.
- **Average or global features:** Fill the feature with a shared value, making inference inputs simpler but providing less positional information.

Another possibility is to encode the feature on a target molecule, as in hotspot conditioning.

## 3. Implement a training transform

**File:** `rf_diffusion/conditions/YOUR_FILE.py`

Use `FindHotspotsTrainingTransform` in `rf_diffusion/ppi.py` as a starting point. Remove unnecessary `__init__` arguments and introduce configuration parameters specific to your condition.

Consider adding `p_shown`: the probability that the condition is exposed during training. If the condition is always shown, inference may also need to supply it consistently. Showing too many different conditions simultaneously can make learning harder.

Example `__call__` method:

```python
def __call__(self, indep, conditions_dict, **kwargs):
    if torch.rand(1) < self.p_shown:
        conditions_dict["MY_NEW_CONDITION"] = calculate_my_condition(indep)

    return kwargs | dict(
        indep=indep,
        conditions_dict=conditions_dict,
    )
```

Refer to the anti-hotspot implementation for a similar pattern.

## 4. Extend `ExpandConditionsDict`

**File:** `rf_diffusion/conditioning.py`

`ExpandConditionsDict` handles expansion of condition tensors when guideposting or atomization introduces additional residues into `indep`. Follow the existing `is_antihotspot` logic to expand your new `conditions_dict` entry in the same way.

## 5. Implement training and inference `extra_tXd` featurizers

**File:** `rf_diffusion/conditions/YOUR_FILE.py`

Start with `get_hotspots_antihotspots_conditioning` in `rf_diffusion/ppi.py`.

The `conditions_dict` is unpacked into the featurizer as keyword arguments, so the function should accept the key that you inserted during the training transform:

```python
def my_condition_featurizer(indep, feature_conf, MY_NEW_CONDITION=None, **kwargs):
    # Convert the condition into the required model feature channels.
    # Return zeros with the correct dimensions when the condition is absent.
    ...
```

The returned tensor must have the required dimensions:

| Feature type | Shape |
| --- | --- |
| 1D condition with `n` channels | `[L, n]` |
| 2D condition with `n` channels | `[L, L, n]` |

The featurizer should return a valid tensor even when the condition is absent; a correctly shaped zero tensor is often appropriate.

Implement an **inference featurizer** that calls the training featurizer, following `get_hotspots_antihotspots_conditioning_inference`. Prefer handling train-versus-inference differences in the transforms so that featurization stays consistent.

## 6. Add inference flags and an inference transform

**Files:**

- `rf_diffusion/config/inference/base.yaml`
- `rf_diffusion/conditions/YOUR_FILE.py`

Decide how users should provide the condition during inference. Options include:

- A residue-level flag analogous to `ppi.antihotspot_res`.
- A scalar value or another parameter in the inference transform's configuration.

If adding a command-line flag, document its format in `base.yaml`. If configuring the transform directly, accept the relevant parameters through its `__init__` method.

Use `HotspotAntihotspotResInferenceTransform` as the example implementation (consult its Python definition and its YAML configuration). The inference transform's `__call__` method should build a condition tensor corresponding to the inference `indep` and insert it into `conditions_dict`.

## 7. Register your transforms and featurizers

**Files:**

- `rf_diffusion/conditioning.py`
- `rf_diffusion/features.py`

In `conditioning.py`, import the new training and inference transforms alongside the existing transforms.

In `features.py`:

1. Import the new module or its featurizer functions.
2. Add the training featurizer to the `featurizers` dictionary.
3. Add the inference featurizer to `inference_featurizers`.

The dictionary keys become the featurizer names used in YAML. Do **not** give a featurizer the same name as its `conditions_dict` key; for example, use `MY_NEW_CONDITION_cond` as the featurizer name for `MY_NEW_CONDITION`.

## 8. Create the training YAML

**Directory:** `rf_diffusion/config/training/`

Copy `fm_tip_ss_adj.yaml` as a starting point. Either replace the SS/ADJ conditioning or add your new condition alongside it. When extending the SS/ADJ configuration, place the new entries directly after the corresponding SS/ADJ entries:

1. Add the new training transform to `upstream_training_transforms.names`, following `GenerateSSADJTrainingTransform`.
2. Add its configuration to `upstream_training_transforms.configs` (including `p_shown`, if applicable).
3. Append the new `extra_tXd` featurizer name to the feature list.
4. Add a corresponding entry to `extra_tXd_params` (an empty configuration may be sufficient, as with `ss_adj_cond`).
5. Adjust `rf.model.d_t1d` and/or `rf.model.d_t2d` to match the number of new channels.

### Update feature channel dimensions

The model's `d_t1d` and `d_t2d` values specify the number of 1D and 2D feature channels.

- Adding one 1D channel increases `d_t1d` by **1**.
- Adding one 2D channel increases `d_t2d` by **1**.
- If you remove SS/ADJ conditioning from this particular configuration, first subtract **5** from `d_t1d` and **4** from `d_t2d`, then add the channels required by the new condition.

Make sure these dimensions match the tensors returned by your featurizers.

## 9. Create the inference YAML

**Directory:** `rf_diffusion/config/inference/`

1. In `base.yaml`, add your new `extra_tXd` method to `inference.conditions`, following `ss_adj_cond`.
2. Copy `aa_ss_adj.yaml` to a new inference configuration.
3. Add the inference transform to `upstream_inference_transforms.names`.
4. Add its configuration to `upstream_inference_transforms.configs`.

If the inference transform takes configuration values rather than command-line flags, supply them in the corresponding transform configuration entry.

## 10. Reshape the starting checkpoint

**Template:** `rf_diffusion/config/training/fm_tip_ss_adj.yaml`

Adding channels generally requires reshaping an existing checkpoint to match the model's expanded inputs. The template includes a commented example:

```yaml
# Example: adjust paths and channel counts for your configuration.
ckpt_load_path: /home/bcov/sc/flow/binder_dev/rf_diffusion/models/rf2a_25c_414_t1d-114.pt
reshape:
  output_path: rf2a_25c_reshaped_t1d-119_t2d-72.pt
```

Temporarily enable and customize this block in your new training YAML, and comment out the original checkpoint-loading setting if necessary. Then, from the directory containing the training scripts, run:

```bash
./reshape_weights.py --config-name=WHATEVER_YOU_CALLED_YOUR_TRAINING_YAML
```

After generating the reshaped checkpoint, update the training config to load it normally and disable the temporary reshaping configuration.

> The checkpoint path and output filename above are examples from the original notes, **not** validated paths for this repository or the `RFD_8.pt`–`RFD_10.pt` checkpoints.

## 11. Test training

On a GPU training node, from the directory containing `train_multi_deep.py`:

```bash
./train_multi_deep.py \
  --config-name=WHATEVER_YOU_CALLED_YOUR_TRAINING_YAML \
  wandb=False benchmark=False epoch_size=24
```

Let the test complete at least one epoch before submitting a full training run.

### Example SLURM submission script

The following is an environment-specific example based on the original notes. Adjust bind mounts, container path, port, and config name for your cluster:

```bash
#!/bin/bash
#SBATCH --ntasks-per-gpu=1

# Select an available port between 10000 and 65535.
export MASTER_PORT=12345
export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)

# Unbuffered output makes training logs appear sooner.
stdbuf -i0 -o0 -e0 srun --unbuffered \
  stdbuf -i0 -o0 -e0 apptainer exec \
  -B /mnt/home/bcov \
  -B /mnt/net/scratch \
  -B /net/scratch \
  -B /software \
  -B /net/software \
  -B /databases \
  -B /net/databases \
  -B /projects/ppi \
  --nv exec/bakerlab_rf_diffusion_aa.sif \
  ./train_multi_deep.py \
  --config-name=WHATEVER_YOU_CALLED_YOUR_TRAINING_YAML \
  wandb=False \
  >> training_log_WHATEVER_YOU_CALLED_YOUR_TRAINING_YAML.log 2>&1
```

## 12. Visualize the condition in PyMOL

`show_dataset.py` contains an example for displaying hotspots. You can adapt that visualization for your condition and configure it through the training YAML.

To communicate with PyMOL on your local computer, choose an available port (`MAGIC_NUMBER`, between 4000 and 65535) and configure the script to use `127.0.0.1:MAGIC_NUMBER` rather than the example host `chesaw.ipd.uw.edu:9123`.

From a terminal on your local computer, open an SSH reverse tunnel to the compute node:

```bash
ssh -R MAGIC_NUMBER:127.0.0.1:MAGIC_NUMBER NODE_YOURE_ON
```

In the local PyMOL Python environment, launch the XML-RPC listener:

```python
import pymol.rpc

pymol.rpc.launch_XMLRPC("localhost", MAGIC_NUMBER)
```

On the compute node, run:

```bash
./show_dataset.py \
  --config-name=WHATEVER_YOU_CALLED_YOUR_TRAINING_YAML \
  zero_weights=True debug=True wandb=False
```

If the tunnel and visualization are configured correctly, structures should appear in PyMOL. To color them by your new condition, extend the display logic following the existing hotspot example.

Example train script (save as train_job.sh and submit like sbatch train_job.sh on digs)
```
#!/bin/bash
##SBATCH --ntasks-per-gpu 1

export MASTER_PORT=13373

export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)

stdbuf -i0 -o0 -e0 srun --unbuffered stdbuf -i0 -o0 -e0 apptainer exec -B /mnt/home/bcov -B /mnt/net/scratch -B /net/scratch -B /software -B /net/software -B /databases -B /net/databases -B /projects/ppi --nv exec/bakerlab_rf_diffusion_aa.sif ./train_multi_deep.py --config-name=ppi_tip_masked_seq_ideal_dhub_pae_cendif_bins wandb=False  >> training_log_ppi_tip_masked_seq_ideal_dhub_pae_cendif_bins_redo.log 2>&1
```
