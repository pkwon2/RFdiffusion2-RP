#!/usr/bin/env python3
"""Generate .ss and .adj tensors from a ligand-containing PDB.

Optionally mask protein-small-molecule adjacency entries.

Example:

PYTHONPATH=/home/pkwon2/rf_diffusion/rf_diffusion_repo:$PYTHONPATH \
/projects/ml/pkwon2/rf_diffusion_repo/rf_diffusion/exec/rf_diffusion_aa.sif \
make_ss_adj_simple.py output_cobalt_renumbered.pdb \
    --aa-model /home/pkwon2/rf_diffusion/rf_diffusion_repo/rf_diffusion/aa_model.py \
    --sec-struct-adjacency /home/pkwon2/rf_diffusion/rf_diffusion_repo/rf_diffusion/conditions/ss_adj/sec_struct_adjacency.py \
    --mask-protein-ligand-adj
"""

import argparse
import importlib.util
import sys
from pathlib import Path

import torch


WATER_NAMES = {"HOH", "WAT", "DOD"}


def load_module(module_name, file_path):
    """Import a Python module directly from a specified .py file."""
    file_path = Path(file_path).resolve()
    if not file_path.is_file():
        raise FileNotFoundError(f"Could not find {file_path}")

    module_dir = str(file_path.parent)
    if module_dir not in sys.path:
        sys.path.insert(0, module_dir)

    spec = importlib.util.spec_from_file_location(module_name, file_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def detect_ligands(pdb_path):
    """Return non-water residue names found in HETATM records."""
    ligands = []

    with open(pdb_path) as f:
        for line in f:
            if not line.startswith("HETATM"):
                continue

            resname = line[17:20].strip()

            if (
                resname
                and resname not in WATER_NAMES
                and resname not in ligands
            ):
                ligands.append(resname)

    return ligands


def mask_protein_ligand_adjacency(adj, indep, mask_value=0):
    """Mask protein <-> small-molecule entries in an adjacency tensor.

    Protein-protein and small-molecule-small-molecule entries are preserved.

    Works for adjacency tensors shaped either:
        (L, L)
        (L, L, C)

    Parameters
    ----------
    adj : torch.Tensor
        Adjacency tensor.
    indep :
        Object returned by aa_model.make_indep().
        Expected to contain indep.is_sm with shape (L,).
    mask_value :
        Value assigned to protein-small-molecule entries.
    """

    if not hasattr(indep, "is_sm"):
        raise AttributeError(
            "indep does not contain an 'is_sm' attribute, so protein and "
            "small-molecule positions cannot be distinguished."
        )

    is_sm = torch.as_tensor(indep.is_sm, dtype=torch.bool).flatten()

    L = adj.shape[0]

    if len(is_sm) != L:
        raise ValueError(
            f"Length mismatch: indep.is_sm has {len(is_sm)} positions, "
            f"but adjacency has shape {tuple(adj.shape)}."
        )

    is_protein = ~is_sm

    # True where exactly one member of the pair is a small molecule.
    #
    # protein -> ligand
    # ligand  -> protein
    #
    # ligand-ligand and protein-protein remain untouched.
    protein_ligand_mask = (
        is_protein[:, None] & is_sm[None, :]
    ) | (
        is_sm[:, None] & is_protein[None, :]
    )

    adj = adj.clone()

    if adj.ndim == 2:
        adj[protein_ligand_mask] = mask_value

    elif adj.ndim == 3:
        adj[protein_ligand_mask, :] = mask_value

    else:
        raise ValueError(
            f"Expected adjacency tensor with 2 or 3 dimensions, "
            f"but got shape {tuple(adj.shape)}."
        )

    print(
        f"Masked {protein_ligand_mask.sum().item()} "
        "protein-small-molecule adjacency pairs."
    )

    return adj


def main():
    parser = argparse.ArgumentParser(
        description="Generate .ss and .adj files from a PDB using make_indep()."
    )

    parser.add_argument(
        "pdb",
        help="Input PDB file",
    )

    parser.add_argument(
        "--aa-model",
        required=True,
        help="Path to aa_model.py",
    )

    parser.add_argument(
        "--sec-struct-adjacency",
        required=True,
        help="Path to sec_struct_adjacency.py",
    )

    parser.add_argument(
        "--ligand",
        default=None,
        help=(
            "Ligand residue name(s) passed to make_indep(), "
            "e.g. 'LIG' or 'LIG,COB'. "
            "If omitted, non-water HETATM residue names are "
            "detected automatically."
        ),
    )

    parser.add_argument(
        "--out-prefix",
        default=None,
        help="Output prefix. Default: input PDB path without .pdb",
    )

    parser.add_argument(
        "--mask-protein-ligand-adj",
        action="store_true",
        help=(
            "Mask adjacency entries between protein positions and "
            "small-molecule positions. Protein-protein and ligand-ligand "
            "entries are left unchanged."
        ),
    )

    args = parser.parse_args()

    pdb_path = Path(args.pdb).resolve()

    if not pdb_path.is_file():
        raise FileNotFoundError(
            f"Could not find input PDB: {pdb_path}"
        )

    aa_model = load_module(
        "aa_model",
        args.aa_model,
    )

    sec_struct_adjacency = load_module(
        "sec_struct_adjacency",
        args.sec_struct_adjacency,
    )

    # ------------------------------------------------------------
    # Determine ligand names
    # ------------------------------------------------------------

    ligand = args.ligand

    if ligand is None:
        ligands = detect_ligands(pdb_path)
        ligand = ",".join(ligands)

    else:
        ligands = [
            x.strip()
            for x in ligand.split(",")
            if x.strip()
        ]

    print(f"PDB:      {pdb_path}")
    print(f"Ligands:  {ligands if ligands else 'none'}")

    # ------------------------------------------------------------
    # Construct Indep
    # ------------------------------------------------------------

    indep = aa_model.make_indep(
        str(pdb_path),
        ligand=ligand,
    )

    if hasattr(indep, "is_sm"):
        is_sm = torch.as_tensor(indep.is_sm).bool().flatten()

        print(
            f"Protein positions:       {(~is_sm).sum().item()}"
        )
        print(
            f"Small-molecule positions: {is_sm.sum().item()}"
        )

    # ------------------------------------------------------------
    # Generate secondary structure + adjacency
    # ------------------------------------------------------------

    ss_adj = sec_struct_adjacency.SecStructAdjacency(
        indep=indep
    )

    ss = ss_adj.ss.cpu()
    adj = ss_adj.adj.cpu()

    # ------------------------------------------------------------
    # Optional protein-small molecule adjacency masking
    # ------------------------------------------------------------

    if args.mask_protein_ligand_adj:
        print(
            "Masking protein <-> small-molecule adjacency..."
        )

        adj = mask_protein_ligand_adjacency(
            adj,
            indep,
            mask_value=0,
        )

    else:
        print(
            "Protein <-> small-molecule adjacency: NOT masked"
        )

    # ------------------------------------------------------------
    # Save
    # ------------------------------------------------------------

    out_prefix = (
        Path(args.out_prefix)
        if args.out_prefix
        else pdb_path.with_suffix("")
    )

    ss_path = Path(
        str(out_prefix) + ".ss"
    )

    adj_path = Path(
        str(out_prefix) + ".adj"
    )

    torch.save(
        ss,
        ss_path,
    )

    torch.save(
        adj,
        adj_path,
    )

    print(f"SS shape:  {tuple(ss.shape)}")
    print(f"ADJ shape: {tuple(adj.shape)}")
    print(f"Saved:     {ss_path}")
    print(f"Saved:     {adj_path}")


if __name__ == "__main__":
    main()