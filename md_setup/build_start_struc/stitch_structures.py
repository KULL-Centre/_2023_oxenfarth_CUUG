import MDAnalysis as mda
from MDAnalysis.analysis import align
import glob, os
import sys

loop_files = sys.argv[1] #'pdb_search/CUUG/CUUG_*.pdb'
stem_file  = sys.argv[2] #'build_aform/CUUG_template_1.pdb'

loop_dir = '/'.join(loop_files.split('/')[:-1])

if len(glob.glob(loop_files))==0:
    print('No input files found.')
    exit()

os.system(f'mkdir {loop_dir}/processed')

for loop_file in sorted(glob.glob(loop_files)):
    u_loop = mda.Universe(loop_file)
    if len(u_loop.residues)==8: # Check if the pdb ist 8 res long
        
        # renumber pdb to match missing loop res in afrom
        loop_file_tmp1 = str('/'.join(loop_file.split('/')[:-1]) + '/processed/' + loop_file.split('/')[-1].split('.pdb')[0]  + '_tmp1.pdb')
        os.system(f'pdb_reres -4 {loop_file} > {loop_file_tmp1}')
        
        # Read the pdbs wich should be stitched together
        u_loop = mda.Universe(loop_file_tmp1)
        u_stem = mda.Universe(stem_file)
        
        # Select the atoms from each pdb that will end up in the chimera pdb
        sel_loop = u_loop.select_atoms("((resid 4 or resid 11) and (name C*' or name O*')) or (resid 5 or resid 10) and not name *H*")
        sel_stem = u_stem.select_atoms("((resid 4 or resid 11) and (name C*' or name O*')) or (resid 5 or resid 10) and not name *H*")
        if len(sel_loop) != len(sel_stem):
            print(f'Selection length doesn\'t match. Check input! Sel1: {len(sel_loop)}; Sel2: {len(sel_stem)}')
            exit()
        
        # Align based on BB of res 4 and 11 and all atoms of res 5 and 10
        align.alignto(u_loop, u_stem, select="((resid 4 or resid 11) and (name C*' or name O*')) or (resid 5 or resid 10) and not name *H*", tol_mass=1000, strict=True)

        
        # Merge the now aligned loop and stem and save as temporary pdb
#        u_chimera = mda.Merge(u_stem.select_atoms('resid 1-4'), u_loop.select_atoms('resid 5-10'), u_stem.select_atoms('resid 11-14'))
        u_chimera = mda.Merge(u_stem.select_atoms('resid 1-4 and not name *H*'), u_loop.select_atoms('resid 5-10 and not name *H*'), u_stem.select_atoms('resid 11-14 and not name *H*'))
        chimera_tmp2 = loop_file_tmp1.split('_tmp1.pdb')[0]+'tmp2.pdb'
        u_chimera.atoms.write(chimera_tmp2)
        
        # Process the temporary pdb to have clean chimeric sturcture
        chimera_final = loop_file_tmp1.split('_tmp1.pdb')[0]+'_aform.pdb'
        os.system(f'pdb_reres -1 {chimera_tmp2} | pdb_reatom -1 | pdb_chain -A > {chimera_final}')
        
        # Delete tmp files
        os.system(f'rm {loop_file_tmp1} {chimera_tmp2}')
        
        # Save with easy to handle name:
        chimera_final_copy = str('/'.join(loop_file.split('/')[:-1]) + '/processed/' + str(chimera_final.split('/')[-1].split('_')[0] + '_' + str(chimera_final.split('/')[-1].split('_')[1]) + '_aform.pdb'))
        os.system(f'cp {chimera_final} {chimera_final_copy}')

    else:
        print(f'Check sequence length: {loop_file}')
        exit()
print('Done.')
