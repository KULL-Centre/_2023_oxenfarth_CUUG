import glob
import os
import sys

in_files = str(sys.argv[1]) #processed/CUUG*pdb*.pdb'

for f in sorted(glob.glob(in_files)):
    new_f = str( '/'.join(f.split('/')[:-1]) + '/' + f.split('/')[-1].split('_')[0] + '_' + str(int(f.split('/')[-1].split('_')[1])+1) + '_aform.pdb')
    print(f'cp {f} {new_f}')

#in_files=sys.argv[1]
#print(sorted(glob.glob(in_files)))
#for f in sorted(glob.glob(in_files)):
#    print(f)
#    new_f = str( '/'.join(f.split('/')[:-1]) + '/' + f.split('/')[-1].split('_')[0] + '_' + str(int(f.split('/')[-1].split('_')[1])+1) + '_aform.pdb')
#    print(f'cp {f} {new_f}')

#for f in sorted(glob.glob(in_files)):
#    print(f)
#    new_f = str('/'.join(loop_file.split('/')[:-1]) + loop_file.split('/')[-1].split('_')[:2] + '_aform.pdb'
#    print('ss')
###    os.system(f'cp {f} {new_f}')
