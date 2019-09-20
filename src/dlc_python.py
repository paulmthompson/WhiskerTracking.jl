
from ruamel.yaml import util
import yaml
import deeplabcut as dlc
import pandas as pd
import numpy as np
import os
import os.path
import glob

def change_dlc_yaml(file_name,my_key,new_body_parts):

    import ruamel.yaml #Hi I'm Python. I suck

    with open(file_name,'r') as mystream:
        cfg,ind,bsi=ruamel.yaml.util.load_yaml_guess_indent(mystream)

    with open(file_name, 'w') as cf:
        ruamelFile = ruamel.yaml.YAML()
        cfg_file,ruamelFile = dlc.utils.create_config_template()

        for key in cfg.keys():
            cfg_file[key]=cfg[key]

        cfg_file[my_key]=new_body_parts

        ruamelFile.dump(cfg_file, cf)

#Helper function for saving a hdf5 file to prepare for deeplabcut. Modified from
# https://github.com/AlexEMG/DeepLabCut/blob/master/deeplabcut/generate_training_dataset/labeling_toolbox.py
def create_label_hdf5(config_path,dir):
    cfg = dlc.auxiliaryfunctions.read_config(config_path)
    scorer = cfg['scorer']
    bodyparts = cfg['bodyparts']

    index =np.sort([fn for fn in glob.glob(os.path.join(dir,'*.png')) if ('labeled.png' not in fn)])
    dataFrame = None

    relativeimagenames=['labeled'+n.split('labeled')[1] for n in index]#[n.split(project_path+'/')[1] for n in index]
    a = np.empty((len(index),2,))
    a[:] = np.nan
    for bodypart in bodyparts:
        index = pd.MultiIndex.from_product([[scorer], [bodypart], ['x', 'y']],names=['scorer', 'bodyparts', 'coords'])
        frame = pd.DataFrame(a, columns = index, index = relativeimagenames)
        dataFrame = pd.concat([dataFrame, frame],axis=1)

    #Sometimes it seems this messes up the label positions.
    #We should replace here
    #for i in range(0,len(myd.index.values)):
    #    old_name=dataFrame.index.values[i]
    #    new_name = dataFrame.index.values[i].replace('/','\\')
    #    dataFrame.rename(index={old_name: new_name},inplace=True)

    dataFrame.to_csv(os.path.join(dir,"CollectedData_" + scorer + ".csv"))
    dataFrame.to_hdf(os.path.join(dir,"CollectedData_" + scorer + '.h5'),'df_with_missing',format='table', mode='w')

def replace_dlc_points(config_path,hdf5_datafile_path,my_w,pointx,pointy):

    cfg = dlc.auxiliaryfunctions.read_config(config_path)
    scorer = cfg['scorer']

    hdf5_datafile = os.path.join(hdf5_datafile_path,"CollectedData_" + scorer + '.h5')

    myd=pd.read_hdf(hdf5_datafile,'df_with_missing')

    for i in range(0,len(my_w)):
        mask = myd['PMT'][my_w[i]]['x'] == i
        myd.loc[:,('PMT',my_w[i],'x')] = pointx[i,:]
        myd.loc[:,('PMT',my_w[i],'y')] = pointy[i,:]

    myd.to_hdf(hdf5_datafile,'df_with_missing',format='table', mode='w')
    myd.to_csv(os.path.join(hdf5_datafile_path,"CollectedData_" + scorer + ".csv"))
