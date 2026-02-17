# Run workflows using AF3

MSAs generated with ColabFold and predictions ran with AlphaFold3.

## 1. Custom prediction

Run modelling of a custom protein or complex.
In this case, MSAs are generated using ColabFold server. Not suitable for RNA modelling.

```bash
bash run_custom.sh example.fa
```
Input file:
```
>Complex1|Q92759_A:Q92759_B:dna_for:dna_rev
FIRSTPROTEIN:SECONDPROTEIN:dna|ACGT:dna|TGCA
```

For more information on how to format an input file, visit [this page](https://github.com/sokrypton/ColabFold?tab=readme-ov-file#including-non-protein-molecules-in-fasta).

## 2. Batch prediction

```bash
bash run_batch.sh [options] input_fasta.fa
```
Input file:
```
>complex_1|protA:protB
FIRSTPROTEIN:SECONDPROTEIN
>complex_2|protA:protB
THIRDPROTEIN:FOURTHPROTEIN
>complex_3|protA:protB
FIFTHPROTEIN:SEVENTHPROTEIN
```