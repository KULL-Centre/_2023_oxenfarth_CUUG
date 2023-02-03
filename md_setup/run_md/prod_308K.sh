#!/bin/bash
#SBATCH --job-name=prod
#SBATCH --partition=qgpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=18
#SBATCH --time=14:00:00
#SBATCH --gres=gpu:v100:1

echo This job is running on the following node\(s\):
echo $SLURM_NODELIST

# Load all required modules for the job
source /comm/specialstacks/gromacs-volta/bin/modules.sh
#module load gromacs-plumed2-master-gcc-8.2.0-openmpi-4.0.3-cuda-10.1/2019.6
module load gromacs-tmpi-gcc-8.2.0-openmpi-4.0.3-cuda-10.1/2021.1
#module load gromacs-gcc-8.2.0-openmpi-4.0.3-cuda-10.1/2021.1

# Force Field 
export GMXLIB="/home/kummerer/TETRALOOPS/forcefields/ff-opc-water-model/:/home/kummerer/TETRALOOPS/ff-opc-water-model/amber_na.ff/"              
echo $GMXLIB

gg=gmx
suffix="cuug_0"
temp="308"
mdp_lib="/home/kummerer/TETRALOOPS/mdp_files/"

cd $SLURM_SUBMIT_DIR
cp ../1-setup/npt_${suffix}.gro ../1-setup/topol_01_${suffix}.top . 

${gg} grompp -f ${mdp_lib}/md_${temp}.mdp -c npt_${suffix}.gro -p topol_01_${suffix}.top -po mdp_12_${suffix}.mdp -o tpr_prod_${suffix}.tpr
#
${gg} mdrun -s tpr_prod_${suffix}.tpr -nb gpu -pme auto -dlb no -npme 0 -deffnm md -ntomp 18 -cpi -maxh 13.9 # -nsteps 100000000 -maxh 13.9 # -plumed plumed.dat
