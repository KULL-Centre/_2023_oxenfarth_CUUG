import bz2
import _pickle as cPickle
import numpy as np

def load_bz2_pkl(inp):
    data = bz2.BZ2File(inp, 'rb')
    data = cPickle.load(data)
    return data

def save_bz2( outfile, results ):
    with bz2.BZ2File(outfile + '.pbz2', 'w' ) as f:
        cPickle.dump(results, f, protocol = 4)

ermsd_matrix = load_bz2_pkl(f'ermsd_matrix_cuug_md_bundle.pbz2')

tmp = np.array(ermsd_matrix[:,:]+ermsd_matrix[:,:].T, dtype=np.float32)

save_bz2(f'ermsd_matrix_cuug_md_bundle_full', tmp)
