
import ruamel.yaml
import yaml
import deeplabcut as dlc

def change_dlc_yaml(file_name,my_key,new_body_parts):

    with open(file_name,'r') as mystream:
        cfg,ind,bsi=ruamel.yaml.util.load_yaml_guess_indent(mystream)

    with open(file_name, 'w') as cf:
        ruamelFile = ruamel.yaml.YAML()
        cfg_file,ruamelFile = dlc.utils.create_config_template()

        for key in cfg.keys():
            cfg_file[key]=cfg[key]

        cfg_file[my_key]=new_body_parts

        ruamelFile.dump(cfg_file, cf)
