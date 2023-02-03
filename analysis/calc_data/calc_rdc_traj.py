#!/usr/bin/python
# calculate RDCs using Pales. A lof of hardcoded stuff, so make sure to check everything!

import mdtraj as md
import subprocess
import os
import pandas as pd
import sys

i = int(sys.argv[1])
stride = int(sys.argv[2])
cuug  = 'PATH/TO/CUUG/SIMULATIONS/' # Change
exp   = 'exp_data/'
pales = '/storage1/kummerer/software/pales/pales-linux' # Needs pales executable

print(f'Calculating RDCs for cuug_{i}. Stride {stride}.')

di_df = pd.DataFrame()
d_df = pd.DataFrame()
for j in range(1,6): # loop over replicates
    print(f'CUUG {i}; sim {j}\r', end='')
    traj_f   = f'{cuug}/cuug_{i}/sim{j}/md_nopbc.xtc'
    top_f    = f'{cuug}/cuug_{i}/sim{j}/initial_nopbc.pdb'
    traj = md.load_xtc(traj_f, top=top_f, stride=stride)
    
    for k,f in enumerate(traj):
        pdb_tmp  = f'{cuug}/analysis/data/rdcs/cuug_{i}/sim{j}/frame_{k}.pdb'
        outd_tmp = f'{cuug}/analysis/data/rdcs/cuug_{i}/sim{j}/rdc_tmp_pf1_{k}.tbl'
        # Save tmp pdb for current frame:
        f.save_pdb(pdb_tmp)
        # Calculate RDCs:
        process = f'{pales} -inD {exp}/cuugrdc_all308.tab -pdb {pdb_tmp} -outD {outd_tmp} -pf1 -H -wv 0.05'
        p       = subprocess.Popen(process, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, universal_newlines=True)
        p.wait()
        os.remove(pdb_tmp)
        # Remove all uneccesary lines:
        process = f"sed -i '0,/^FORMAT/d' {outd_tmp}"
        p       = subprocess.Popen(process, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, universal_newlines=True)
        p.wait()
        # Read outfile:
        df_tmp = pd.read_csv(outd_tmp, delim_whitespace=True, names=['RESID_I','RESNAME_I','ATOMNAME_I','RESID_J','RESNAME_J','ATOMNAME_J','DI','D_OBS','D','D_DIFF','DD','W'])
        names  = [f"{r[1]['RESNAME_I'][0]}{r[1]['RESID_I']}_{r[1]['ATOMNAME_I']}-{r[1]['ATOMNAME_J']}" for r in df_tmp.iterrows()]
        di_tmp = [float(v) for v in df_tmp['DI']]
        d_tmp  = [float(v) for v in df_tmp['D']]
        # Add Di values to one df:
        di_df = di_df.append(dict(zip(names,di_tmp)), ignore_index=True)
        # Add D valuesto another df:
        d_df = d_df.append(dict(zip(names,d_tmp)), ignore_index=True)
        os.remove(outd_tmp)
    
di_df.to_pickle(f'{cuug}/cuug_{i}/di_df_pf1.pkl')
d_df.to_pickle(f'{cuug}/cuug_{i}/d_df_pf1.pkl')
print(f'{d_df.shape[1]} Di & D for {d_df.shape[0]} frames saved as pickle.')
