import mdtraj as md
import barnaba as bb
import numpy as np
import bz2
import _pickle as cPickle


def save_bz2( outfile, results ):
    with bz2.BZ2File(outfile + '.pbz2', 'w' ) as f:
        cPickle.dump(results, f, protocol = 4)

all_traj = []
traj_f   = f'../md_plus_exp_subsampled.pdb'
top_f    = f'../md_plus_exp_subsampled.pdb'

trajj     = md.load(traj_f, top=top_f)
print(trajj)

N = trajj.n_frames
matrix = np.zeros((N, N), dtype=np.float16)
for i in range(N):
    if i % 10 == 0:
        print(f'{i+10}/{N} frames processed.')
    ermsd_ = bb.ermsd_traj(trajj[i],trajj[i:],cutoff=2.4,residues_ref=[5,6,7,8,9,10],residues_target=[5,6,7,8,9,10])
    matrix[i,i:] = ermsd_

save_bz2('ermsd_matrix_cuug_md_bundle', matrix)
