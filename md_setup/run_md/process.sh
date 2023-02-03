#!/bin/bash
#SBATCH --job-name=pro
#SBATCH --partition=qgpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=01:00:00

# Load all required modules for the job
source /comm/specialstacks/gromacs-volta/bin/modules.sh
module load plumed2-gcc-8.2.0-openmpi-4.0.3/2.7.3
module load gromacs-tmpi-gcc-8.2.0-openmpi-4.0.3-cuda-10.1/2021.1

gg=gmx

cd $SLURM_SUBMIT_DIR

plumed driver --mf_xtc md.xtc --plumed plumed_check.dat

${gg} trjconv -s tpr_prod_*.tpr -f md.xtc -center -pbc mol -b 0 -e 0 -o initial_nopbc.pdb <<-EOF
RNA
RNA
EOF

${gg} trjconv -s tpr_prod_*.tpr -f md.xtc -center -pbc mol -o md_nopbc.xtc <<-EOF
RNA
RNA
EOF

${gg} mindist -f md.xtc -s tpr_prod_*.tpr -pi -xvg none <<-EOF
RNA
EOF
