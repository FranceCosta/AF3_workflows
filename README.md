# Run workflows using AF3

MSAs are generated with the ColabFold server and predictions are run with AlphaFold3.

## 1. Custom prediction

Run modelling of a custom protein or complex.

```bash
bash run_custom.sh example.fa
```
Input file:
```
>Complex1|Q92759_A:Q92759_B:dna_for:dna_rev
FIRSTPROTEIN:SECONDPROTEIN:dna|ACGT:dna|TGCA
```

For more information on how to format an input file, visit [this page](https://github.com/sokrypton/ColabFold?tab=readme-ov-file#including-non-protein-molecules-in-fasta).