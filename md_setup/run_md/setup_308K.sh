#!/bin/bash
#SBATCH --job-name=setup
#SBATCH --partition=qgpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=18
#SBATCH --time=00:30:00
#SBATCH --gres=gpu:v100:1

# Load all required modules for the job
source /comm/specialstacks/gromacs-volta/bin/modules.sh
#module load gromacs-gcc-8.2.0-openmpi-4.0.3-cuda-10.1/2021.1
module load gromacs-plumed2-master-gcc-8.2.0-openmpi-4.0.3-cuda-10.1/2019.6

# Force Field 
export GMXLIB="/home/kummerer/TETRALOOPS/forcefields/ff-opc-water-model/:/home/kummerer/TETRALOOPS/ff-opc-water-model/amber_na.ff/"              
echo $GMXLIB

gg=gmx_mpi
init_pdb="CUUG_0_aform.pdb"
suffix="cuug_0"
temp="308"
mdp_lib="/home/kummerer/TETRALOOPS/mdp_files/"

cd $SLURM_SUBMIT_DIR

# it will ask for FF and water model. choose amber_na.ff and OPC water model SCYLLA: 16 - 6
${gg} pdb2gmx -f ${init_pdb} -ignh -o conf_01_${suffix}.gro -p topol_01_${suffix}.top -i posre.itp <<EOF
1
6
EOF

sed -i "s/1000  1000  1000/POSRES_RNA   POSRES_RNA   POSRES_RNA/g" posre.itp

#exit
# Step 02 - Prepare for vacuum minimization
${gg} grompp -f ${mdp_lib}/mini.mdp -c conf_01_${suffix}.gro -p topol_01_${suffix}.top -po mdp_02_${suffix}.mdp -o tpr_mini_${suffix}.tpr

# Step 03 - Run minimization in vacuum
${gg} mdrun -s tpr_mini_${suffix}.tpr -deffnm mini_${suffix}

#############################################
# Step 04 - Define simulation box
${gg} editconf -bt dodecahedron -d 1.4 -f mini_${suffix}.gro -o conf_04_${suffix}.gro

# Step 05 - Add Water molecules OPC
${gg} solvate -cp conf_04_${suffix}.gro -p topol_01_${suffix}.top -cs opc.gro -o conf_05_${suffix}.gro 
#${gg} solvate -cp conf_04.gro -p topol_01.top -cs opc.gro   -o conf_05.gro 

# Step 06 - Prepare for minimization in water. Maxwarn is set to 1 because otherwise it complains about the non=zero charge (issue fixed below)
${gg} grompp -f ${mdp_lib}/mini_wat_posre.mdp -c conf_05_${suffix}.gro -p topol_01_${suffix}.top -po mdp_06_${suffix}.mdp -o mini_water_tmp_${suffix}.tpr -maxwarn 1 -r conf_05_${suffix}.gro

# Step 7 neutralize w KCL ions
echo "SOL" | ${gg} genion -pname K -nname CL -s mini_water_tmp_${suffix}.tpr -o conf_07_${suffix}.gro -p topol_01_${suffix}.top -neutral -conc 0.01 

# Step 08 - Prepare for minimization in water (again) 
${gg} grompp -f ${mdp_lib}/mini_wat_posre.mdp -c conf_07_${suffix}.gro -p topol_01_${suffix}.top -po mdp_08_${suffix}.mdp -o mini_water_${suffix}.tpr -maxwarn 1 -r conf_07_${suffix}.gro

# Step 09 - Run minimization in water#
#export OMP_NUM_THREADS=64 # check this

${gg} mdrun -s mini_water_${suffix}.tpr -deffnm mini_water_${suffix} -ntomp 18 -npme 0 -notunepme -pin o
#############################################

# Step 10 NVT EQUILIBRATION
${gg} grompp -f ${mdp_lib}/equil_nvt_${temp}_posre.mdp -c mini_water_${suffix}.gro -p topol_01_${suffix}.top -po mdp_10_${suffix}.mdp -o tpr_nvt_${suffix}.tpr -maxwarn 1 -r mini_water_${suffix}.gro
${gg} mdrun -s tpr_nvt_${suffix}.tpr -deffnm nvt_${suffix} -ntomp 18 -npme 0 -notunepme -pin o

# step 11 NPT equilibration: Gradually lower restraints on the RNA
cnt=1
cntmax=9

while [ ${cnt} -le ${cntmax} ]; do
	pcnt=$[${cnt}-1]
	if [ ${cnt} == 1 ]; then
		${gg} grompp -f ${mdp_lib}/equil_npt_${temp}_posre${cnt}.mdp -c nvt_${suffix}.gro -t nvt_${suffix}.cpt -p topol_01_${suffix}.top -o tpr_npt_${suffix}_${cnt}.tpr -maxwarn 1 -po mdout_npt${cnt}.mdp -r nvt_${suffix}.gro
		${gg} mdrun -deffnm npt_${suffix}_${cnt}  -s tpr_npt_${suffix}_${cnt}.tpr -ntomp 18 -npme 0 -notunepme -pin o
	else
		${gg} grompp -f ${mdp_lib}/equil_npt_${temp}_posre${cnt}.mdp -c npt_${suffix}_${pcnt}.gro -t npt_${suffix}_${pcnt}.cpt -p topol_01_${suffix}.top -o tpr_npt_${suffix}_${cnt}.tpr -maxwarn 1 -po mdout_npt${cnt}.mdp -r npt_${suffix}_${pcnt}.gro
		${gg} mdrun -deffnm npt_${suffix}_${cnt}  -s tpr_npt_${suffix}_${cnt}.tpr -ntomp 18 -npme 0 -notunepme -pin o
	fi
	cnt=$[${cnt}+1]
done
# Last one without any restraints
${gg} grompp -f ${mdp_lib}/equil_npt_${temp}.mdp -c npt_${suffix}_${pcnt}.gro -t npt_${suffix}_${pcnt}.cpt -p topol_01_${suffix}.top -o tpr_npt_${suffix}.tpr -maxwarn 1 -r npt_${suffix}_${pcnt}.gro
${gg} mdrun -deffnm npt_${suffix}  -s tpr_npt_${suffix}.tpr -ntomp 18 -npme 0 -notunepme -pin o

# Create pdb for eRMSD calculation (initial.pdb):
${gg} trjconv -f npt_${suffix}.xtc -s tpr_npt_${suffix}.tpr -center -pbc mol -b 200 -e 200 -o initial.pdb <<EOF
RNA
RNA
EOF
#
##export OMP_NUM_THREADS=28 # check this
##step 12 - Prepare production tpr (NVT - standard choice when doing REMD/REST)
#${gg} grompp -f ${mdp_lib}/md_${temp}.mdp -c npt_${suffix}.gro -p topol_01_${suffix}.top -po mdp_12_${suffix}.mdp -o tpr_prod_${suffix}.tpr
##${gg} grompp -f ${mdp_lib}/md_${temp}.mdp -c npt_${suffix}.gro -p topol_01_${suffix}.top -pp processed.top
## tpr_prod_${suffix}.tpr is your prduction tpr file
#
#${gg} mdrun -s tpr_prod_${suffix}.tpr -o traj_prod_${suffix}.trr -x traj_prod_${suffix}.xtc -g log_prod_${suffix}.log -c config.gro -ntomp 28 -maxh 0.1 -plumed plumed.dat
