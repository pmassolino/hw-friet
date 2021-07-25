#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#--------------------------------------------------------------------------------#
# Implementation by Pedro Maat C. Massolino,                                     #
# hereby denoted as "the implementer".                                           #
#                                                                                #
# To the extent possible under law, the implementer has waived all copyright     #
# and related or neighboring rights to the source code in this file.             #
# http://creativecommons.org/publicdomain/zero/1.0/                              #
#--------------------------------------------------------------------------------#

import os
import sys
import io
import math
import csv
import hashlib

def create_unique_synthesis_filename(entity_name, synthesis_extra_parameters, timing_constraint=None):
    # Create unique filename output
    full_bytearray_id = bytearray()
    for parameter_key, parameter_value in synthesis_extra_parameters.items():
        if((parameter_value != None) and (parameter_value != '')):
            full_bytearray_id = full_bytearray_id + parameter_key.encode(encoding="utf-8")
            full_bytearray_id = full_bytearray_id + parameter_value.encode(encoding="utf-8")
    hash = hashlib.sha1()
    hash.update(full_bytearray_id)
    unique_identifier = ((hash.digest()).hex())[0:8]
    synthesis_filename_output = ''
    synthesis_filename_output = synthesis_filename_output + entity_name
    if((timing_constraint != None)):
        synthesis_filename_output = synthesis_filename_output + '__t_' + timing_constraint
    synthesis_filename_output = synthesis_filename_output + '__' + unique_identifier
    return synthesis_filename_output

def read_csv_synth_file(csv_synth_filename):
    with open(csv_synth_filename, newline='') as csv_synth_file:
        reader = csv.DictReader(csv_synth_file,restval=None)
        all_synthesis_options = [row for row in reader]
    return all_synthesis_options

def split_synthesis_options(all_synthesis_options, main_synthesis_parameters):
    all_main_synthesis_options = []
    all_synthesis_extra_parameters = []
    for each_synthesis_option in all_synthesis_options:
        main_row = {}
        extra_row = dict(each_synthesis_option)
        # Split the content into the main ones and everything else
        for each_synthesis_parameter in main_synthesis_parameters:
            main_row[each_synthesis_parameter] = extra_row[each_synthesis_parameter]
            del extra_row[each_synthesis_parameter]
        all_main_synthesis_options += [main_row]
        all_synthesis_extra_parameters += [extra_row]
        
    return all_main_synthesis_options, all_synthesis_extra_parameters

def synthesize_asic_entity(yosys_location, yosys_synth_script, all_target_cells, verilog_source_folder, synthesis_options, synthesis_extra_parameters, synthesis_output_folder):
    # Try to access the asic cell asked
    target_cell = all_target_cells[synthesis_options['STD_CELL_NAME']]
    # Check if folder exists, and if not create
    if(not os.path.isdir(synthesis_output_folder)):
        os.mkdir(synthesis_output_folder)
    # Check if folder exists for the synthesis script, if not, create it
    int_synthesis_output_folder = synthesis_output_folder + '/' + yosys_synth_script[:-4]
    if(not os.path.isdir(int_synthesis_output_folder)):
        os.mkdir(int_synthesis_output_folder)
    # Check if folder exists for the target cell, if not, create it
    int_synthesis_output_folder = int_synthesis_output_folder + '/' + target_cell['name']
    if(not os.path.isdir(int_synthesis_output_folder)):
        os.mkdir(int_synthesis_output_folder)
    # Create unique filename output
    synthesis_filename_output = create_unique_synthesis_filename(synthesis_options['ENTITY_NAME'], synthesis_extra_parameters, synthesis_options['TIMING_CONSTRAINT'])
    # Create extra parameters 
    filtered_total_synthesis_extra_parameters = 0
    command_top_parameters = ''
    for parameter_key, parameter_value in synthesis_extra_parameters.items():
        if((parameter_value != None) and (parameter_value != '')):
            command_top_parameters = command_top_parameters + 'SYNTH_VERILOG_TOP_PARAMETER_NAME_' + str(filtered_total_synthesis_extra_parameters) + '=' + parameter_key + ' '
            command_top_parameters = command_top_parameters + 'SYNTH_VERILOG_TOP_PARAMETER_VALUE_' + str(filtered_total_synthesis_extra_parameters) + '=' + parameter_value + ' '
            filtered_total_synthesis_extra_parameters = filtered_total_synthesis_extra_parameters + 1
    # Create all enviroment variables for the TCL script
    command = ''
    command = command + 'SYNTH_VERILOG_FILES_FOLDER=' + verilog_source_folder + ' '
    command = command + 'SYNTH_TOP_UNIT_NAME=' + synthesis_options['ENTITY_NAME'] + ' '
    command = command + 'SYNTH_ASIC_CELL_LOCATION=' + target_cell['liberty_file'] + ' '
    command = command + 'SYNTH_ASIC_PIN_CONSTRAINTS=' + target_cell['pin_constr_file'] + ' '
    command = command + 'SYNTH_TIMING_CONSTRAINT=' + synthesis_options['TIMING_CONSTRAINT'] + ' '
    command = command + 'SYNTH_OUTPUT_CIRCUIT_FOLDER=' + int_synthesis_output_folder + ' '
    command = command + 'SYNTH_OUTPUT_CIRCUIT_FILENAME=' + synthesis_filename_output + ' '
    command = command + 'SYNTH_VERILOG_TOP_NUMBER_PARAMETERS=' + str(filtered_total_synthesis_extra_parameters) + ' '
    command = command + command_top_parameters
    log_filename = int_synthesis_output_folder + '/' + synthesis_filename_output + '.yslog'
    command = command + yosys_location + ' -l ' + log_filename + ' -c ' + yosys_synth_script + ' -q'
    print(command)
    os.system(command)
    
    # Open log and look for the delay and area results
    result_filename = int_synthesis_output_folder + '/' + synthesis_filename_output + '.result'
    # Area string to look for
    area_result_line_1 = 'Chip area for module ' + "'" + "\\" +  synthesis_options['ENTITY_NAME'] + "':"
    area_result_line_2 = 'Chip area for top module ' + "'" + "\\" + synthesis_options['ENTITY_NAME'] + "':"
    possible_area_result_lines = []
    # Delay string to look for
    delay_result_line = 'Delay ='
    possible_delay_result_lines = []
    with open(log_filename, "r") as log_file:
        for log_line in log_file:
            if (delay_result_line in log_line):
                possible_delay_result_lines += [log_line]
            if (area_result_line_1 in log_line):
                possible_area_result_lines += [log_line]
            if (area_result_line_2 in log_line):
                possible_area_result_lines += [log_line]
    # Only write the biggest area found for the top architecture
    if(len(possible_area_result_lines) <= 1):
        biggest_area_line = 0
    else:
        biggest_area_line = 0
        temp_line_splitted = possible_area_result_lines[0].split(":")
        biggest_area_line_result = float((temp_line_splitted[1]).strip())
        for i in range(1, len(possible_area_result_lines)):
            temp_line_splitted = possible_area_result_lines[i].split(":")
            temp_area_line_result = float((temp_line_splitted[1]).strip())
            if(temp_area_line_result > biggest_area_line_result):
                biggest_area_line = i
                biggest_area_line_result = temp_area_line_result
    # Only write the first delay found. This needs to be redone, because ABC doesn't give proper delay results for non flattened results.
    with open(result_filename, "w") as result_file:
        result_file.write(possible_area_result_lines[biggest_area_line])
        result_file.write(possible_delay_result_lines[0])

def synthesize_simple_entity(yosys_location, yosys_synth_script, verilog_source_folder, entity_name, each_extra, synthesis_output_folder):
    # Check if folder exists, and if not create
    if(not os.path.isdir(synthesis_output_folder)):
        os.mkdir(synthesis_output_folder)
    # Check if folder exists for the synthesis script, if not, create it
    int_synthesis_output_folder = synthesis_output_folder + '/' + yosys_synth_script[:-4]
    if(not os.path.isdir(int_synthesis_output_folder)):
        os.mkdir(int_synthesis_output_folder)
    # Create unique filename output
    synthesis_filename_output = create_unique_synthesis_filename(entity_name, each_extra, None)
    # Create extra parameters 
    filtered_total_extra_parameters = 0
    command_top_parameters = ''
    for parameter_key, parameter_value in each_extra.items():
        if((parameter_value != None) and (parameter_value != '')):
            command_top_parameters = command_top_parameters + 'SYNTH_VERILOG_TOP_PARAMETER_NAME_' + str(filtered_total_extra_parameters) + '=' + parameter_key + ' '
            command_top_parameters = command_top_parameters + 'SYNTH_VERILOG_TOP_PARAMETER_VALUE_' + str(filtered_total_extra_parameters) + '=' + parameter_value + ' '
            filtered_total_extra_parameters = filtered_total_extra_parameters + 1
    # Create all enviroment variables for the TCL script
    command = ''
    command = command + 'SYNTH_VERILOG_FILES_FOLDER=' + verilog_source_folder + ' '
    command = command + 'SYNTH_TOP_UNIT_NAME=' + entity_name + ' '
    command = command + 'SYNTH_OUTPUT_CIRCUIT_FOLDER=' + int_synthesis_output_folder + ' '
    command = command + 'SYNTH_OUTPUT_CIRCUIT_FILENAME=' + synthesis_filename_output + ' '
    command = command + 'SYNTH_VERILOG_TOP_NUMBER_PARAMETERS=' + str(filtered_total_extra_parameters) + ' '
    command = command + command_top_parameters
    log_filename = int_synthesis_output_folder + '/' + synthesis_filename_output + '.yslog'
    command = command + yosys_location + ' -l ' + log_filename + ' -c ' + yosys_synth_script + ' -q'
    
    print(command)
    os.system(command)

def synthesize_asic_list(yosys_location, all_yosys_synth_scripts, all_target_cells, verilog_source_folder, all_main_synthesis_options,all_synthesis_extra_parameters, synthesis_output_folder):
    for each_yosys_synth_script in all_yosys_synth_scripts:
       for i in range(0,len(all_main_synthesis_options)):
           synthesize_asic_entity(yosys_location, each_yosys_synth_script, all_target_cells, verilog_source_folder, all_main_synthesis_options[i],all_synthesis_extra_parameters[i], synthesis_output_folder)

def synthesize_simple_list(yosys_location, all_yosys_synth_scripts, verilog_source_folder, all_main_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder):
    selected_entity_names_extras_duplicated = [(all_main_synthesis_options[i]['ENTITY_NAME'], tuple((all_synthesis_extra_parameters[i]).items())) for i in range(len(all_main_synthesis_options))]
    selected_entity_names_extras = list(set(selected_entity_names_extras_duplicated))
    for each_yosys_synth_script in all_yosys_synth_scripts:
        for (each_entity_name,each_extra_key_values) in selected_entity_names_extras:
            each_extra = {k: v for k,v in each_extra_key_values}
            synthesize_simple_entity(yosys_location, each_yosys_synth_script, verilog_source_folder, each_entity_name, each_extra, synthesis_output_folder)

def generate_csv_with_all_results(all_yosys_asic_synth_script, all_target_cells, all_main_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder):
    area_result_line = 'Chip area'
    delay_result_line = 'Delay ='
    csv_file_name = synthesis_output_folder + '/' + 'results.csv'
    for each_yosys_synth_script in all_yosys_asic_synth_script:
        with io.open(csv_file_name, "w", encoding="utf-8") as csv_file:
            fieldnames = ['ENTITY_NAME', 'TECHNOLOGY', 'TIMING_CONSTRAINT']
            # Add extra parameters
            for parameter_key in all_synthesis_extra_parameters[0].keys():
                fieldnames = fieldnames + [parameter_key]
            fieldnames = fieldnames + ['AREA', 'GE', 'DELAY']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for i in range(len(all_main_synthesis_options)):
                each_synthesis_main_option = all_main_synthesis_options[i]
                each_synthesis_extra_option = all_synthesis_extra_parameters[i]
                each_std_cell = all_target_cells[each_synthesis_main_option['STD_CELL_NAME']]
                nand_size = 0.0
                with open(each_std_cell['nand_file'], "r") as nand_file:
                    nand_size = float(nand_file.readline())
                row = {}
                row['ENTITY_NAME'] = each_synthesis_main_option['ENTITY_NAME']
                row['TECHNOLOGY'] = each_std_cell['name']
                row['TIMING_CONSTRAINT'] = each_synthesis_main_option['TIMING_CONSTRAINT']
                # Write extra options
                for parameter_key, parameter_value in each_synthesis_extra_option.items():
                    row[parameter_key] = parameter_value
                # Recover unique filename output
                synthesis_filename_output = create_unique_synthesis_filename(each_synthesis_main_option['ENTITY_NAME'], each_synthesis_extra_option, each_synthesis_main_option['TIMING_CONSTRAINT'])
                result_filename = synthesis_output_folder + '/' + each_yosys_synth_script[:-4] + '/' + each_std_cell['name'] + '/' + synthesis_filename_output + '.result'
                with open(result_filename, "r") as result_file:
                    for result_line in result_file:
                        if(area_result_line in result_line):
                            area_line_splitted = result_line.split(":")
                            area_result = (area_line_splitted[1]).strip()
                            row['AREA'] = area_result
                area_result_ge = str(int(math.ceil(float(area_result)/nand_size)))
                row['GE'] = area_result_ge
                with open(result_filename, "r") as result_file:
                    for result_line in result_file:
                        if(delay_result_line in result_line):
                            delay_line_splitted = result_line.split(delay_result_line)
                            delay_result = ((delay_line_splitted[1]).split())[0]
                            row['DELAY'] = delay_result
                writer.writerow(row)

def generate_simulation_synthesized_design(yosys_synth_script, all_target_cells, synthesis_options, synthesis_extra_parameters, synthesis_output_folder, testbench_folder):
    # Try to access the asic cell asked
    target_cell = all_target_cells[synthesis_options['STD_CELL_NAME']]
    # Get the testbench file path
    testbench_synthesized_entity = testbench_folder + '/' + synthesis_options['TB_ENTITY_NAME'] + '.v'
    if(os.path.exists(testbench_synthesized_entity)):
        synthesis_filename_output = create_unique_synthesis_filename(synthesis_options['ENTITY_NAME'], synthesis_extra_parameters, synthesis_options['TIMING_CONSTRAINT'])
        testbench_synthesis_filename_output = create_unique_synthesis_filename(synthesis_options['TB_ENTITY_NAME'], synthesis_extra_parameters, synthesis_options['TIMING_CONSTRAINT'])
                
        synthesized_entity = synthesis_output_folder + '/' + yosys_synth_script[:-4] + '/' + target_cell['name'] + '/' + synthesis_filename_output + '.v'
        cell_library_verilog = target_cell['verilog_library']
        output_folder = synthesis_output_folder + '/' + yosys_synth_script[:-4] + '/' + 'sim_' + target_cell['name']
        if(not os.path.isdir(output_folder)):
            os.mkdir(output_folder)
        simulation_testbench = output_folder + '/' + testbench_synthesis_filename_output + '_design '
        
        command = 'iverilog -s ' + synthesis_options['TB_ENTITY_NAME'] + ' -o ' + simulation_testbench + ' ' + testbench_synthesized_entity + ' ' + synthesized_entity + ' ' + cell_library_verilog
        print(command)
        os.system(command)

def generate_all_simulation_synthesized_design(all_yosys_synth_scripts, all_target_cells, all_main_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder, testbench_folder):
    for each_yosys_synth_ecript in all_yosys_synth_scripts:
        for i in range(0,len(all_main_synthesis_options)):
            generate_simulation_synthesized_design(each_yosys_synth_ecript, all_target_cells, all_main_synthesis_options[i], all_synthesis_extra_parameters[i], synthesis_output_folder, testbench_folder)

def generate_simulation_simple_synthesized_design(yosys_synth_script, synthesis_options, synthesis_extra_parameters, synthesis_output_folder, testbench_folder):
    testbench_synthesized_entity = testbench_folder + '/' + synthesis_options['TB_ENTITY_NAME'] + '.v'
    if(os.path.exists(testbench_synthesized_entity)):
        synthesis_filename_output = create_unique_synthesis_filename(synthesis_options['ENTITY_NAME'], synthesis_extra_parameters, None)
        testbench_synthesis_filename_output = create_unique_synthesis_filename(synthesis_options['TB_ENTITY_NAME'], synthesis_extra_parameters, None)
        
        synthesized_entity = synthesis_output_folder + '/' + yosys_synth_script[:-4] + '/' + synthesis_filename_output + '.v'
        output_folder = synthesis_output_folder + '/' + yosys_synth_script[:-4] + '/' + 'sim'
        if(not os.path.isdir(output_folder)):
            os.mkdir(output_folder)
        simulation_testbench = output_folder + '/' + testbench_synthesis_filename_output + '_design '
        
        command = 'iverilog -s ' + synthesis_options['TB_ENTITY_NAME'] + ' -o ' + simulation_testbench + ' ' + testbench_synthesized_entity + ' ' + synthesized_entity
        print(command)
        os.system(command)

def generate_all_simulation_simple_synthesized_design(all_yosys_synth_scripts, all_main_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder, testbench_folder):
    for each_yosys_synth_ecript in all_yosys_synth_scripts:
        for i in range(0,len(all_main_synthesis_options)):
            generate_simulation_simple_synthesized_design(each_yosys_synth_ecript, all_main_synthesis_options[i], all_synthesis_extra_parameters[i], synthesis_output_folder, testbench_folder)

# STD cells descriptions

asic_cells_base_folder = '../../../asic_cells/'

gscl45nm_library = {
'name' : 'gscl45nm',
'liberty_file' : asic_cells_base_folder + 'gscl45nm/gscl45nm.lib',
'pin_constr_file' : asic_cells_base_folder + 'gscl45nm/gscl45nm.constr',
'nand_file' : asic_cells_base_folder + 'gscl45nm/gscl45nm.nand',
'verilog_library' : asic_cells_base_folder + 'gscl45nm/gscl45nm.v',
}

nangate1_library = {
'name' : 'NangateOpenCellLibrary_typical_ccs',
'liberty_file' : asic_cells_base_folder + 'NangateOpenCellLibrary_typical_ccs/NangateOpenCellLibrary_typical_ccs.lib',
'pin_constr_file' : asic_cells_base_folder + 'NangateOpenCellLibrary_typical_ccs/NangateOpenCellLibrary_typical_ccs.constr',
'nand_file' : asic_cells_base_folder + 'NangateOpenCellLibrary_typical_ccs/NangateOpenCellLibrary_typical_ccs.nand',
'verilog_library' : asic_cells_base_folder + 'NangateOpenCellLibrary_typical_ccs/NangateOpenCellLibrary_typical_ccs.v',
}

# Adding cells to the list

all_std_cells_libraries = {}

all_std_cells_libraries[gscl45nm_library['name']] = gscl45nm_library
all_std_cells_libraries[nangate1_library['name']] = nangate1_library

yosys_location = 'yosys'
all_yosys_asic_synth_script = ['synth_asic.tcl']
all_yosys_simple_synth_script = ['synth_simple.tcl']

# All testbench names

testbench_folder = '../verilog_source'

# FIX THIS
all_entity_names = []
all_testbench_names = [('tb_' + each_entity_name) for each_entity_name in all_entity_names]

# Synthesis output folder

synthesis_output_folder = 'synth_out'

# Verilog source folder

verilog_source_folder = '../verilog_source'

# All synthesis options CSV file

csv_synth_filename = 'synth_list.csv'
main_synthesis_parameters = []
main_synthesis_parameters += ['STD_CELL_NAME']
main_synthesis_parameters += ['ENTITY_NAME']
main_synthesis_parameters += ['TIMING_CONSTRAINT']
main_synthesis_parameters += ['TB_ENTITY_NAME']

if __name__ == "__main__" :
    help_string = ''
    help_string += 'This is a basic synthesizes script, you should only use one option per call' + os.linesep
    help_string += 'This script reads the file synth_list.csv where it loads all possible syntheis options' + os.linesep
    help_string += os.linesep + os.linesep
    help_string += 'Synthesize all possibilities in synth_list.csv for ASIC and simple' + os.linesep
    help_string += 'synth.py -all' + os.linesep
    help_string += os.linesep
    help_string += 'Synthesize all possibilities in synth_list.csv only ASIC' + os.linesep
    help_string += 'synth.py -asic' + os.linesep
    help_string += os.linesep
    help_string += 'Synthesize all possibilities in synth_list.csv only simple' + os.linesep
    help_string += 'synth.py -simple' + os.linesep
    help_string += os.linesep
    help_string += 'You can also perform a full batch by listing all combinations in CSV file' + os.linesep
    help_string += 'It is also possible to perform a filtering to which values are allowed' + os.linesep
    help_string += 'synth.py -l [filter_colunm_name=value] [filter_colunm_name=value]' + os.linesep
    help_string += os.linesep
    help_string += 'If you want to generate asic csv report use -g' + os.linesep
    help_string += 'synth.py -g' + os.linesep
    help_string += os.linesep
    help_string += 'Generates the simulation executables of the synthesized design with icarus' + os.linesep
    help_string += 'synth.py -sim' + os.linesep
    help_string += os.linesep
    
    if(len(sys.argv) == 1):
        print(help_string)
    else:
        all_synthesis_options = read_csv_synth_file(csv_synth_filename)
        if((sys.argv[1] == '-all') or (sys.argv[1] == '-asic') or (sys.argv[1] == '-simple')):
            all_main_synthesis_options, all_synthesis_extra_parameters = split_synthesis_options(all_synthesis_options, main_synthesis_parameters)
            if((sys.argv[1] == '-all') or (sys.argv[1] == '-asic')):
                synthesize_asic_list(yosys_location, all_yosys_asic_synth_script, all_std_cells_libraries, verilog_source_folder, all_main_synthesis_options,all_synthesis_extra_parameters, synthesis_output_folder)
            if((sys.argv[1] == '-all') or (sys.argv[1] == '-simple')):
                synthesize_simple_list(yosys_location, all_yosys_simple_synth_script, verilog_source_folder, all_main_synthesis_options,all_synthesis_extra_parameters, synthesis_output_folder)
        elif(sys.argv[1] == '-l'):
            selected_synthesis_options = []
            for each_synthesis_option in all_synthesis_options:
                valid_option = True
                for each_string_constraint in sys.argv[2:]:
                    each_string_constraint_key, each_string_constraint_value = (each_string_constraint.strip()).split('=')
                    if(each_synthesis_option[each_string_constraint_key] != each_string_constraint_value):
                        valid_option = False
                if(valid_option):
                    selected_synthesis_options += [each_synthesis_option]
            all_selected_synthesis_options, all_synthesis_extra_parameters = split_synthesis_options(selected_synthesis_options, main_synthesis_parameters)
            synthesize_asic_list(yosys_location, all_yosys_asic_synth_script, all_std_cells_libraries, verilog_source_folder, all_selected_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder)
            synthesize_simple_list(yosys_location, all_yosys_simple_synth_script, verilog_source_folder, all_selected_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder)
        elif(sys.argv[1] == '-g'):
            all_main_synthesis_options, all_synthesis_extra_parameters = split_synthesis_options(all_synthesis_options, main_synthesis_parameters)
            generate_csv_with_all_results(all_yosys_asic_synth_script, all_std_cells_libraries, all_main_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder)
        elif(sys.argv[1] == '-sim'):
            all_main_synthesis_options, all_synthesis_extra_parameters = split_synthesis_options(all_synthesis_options, main_synthesis_parameters)
            generate_all_simulation_synthesized_design(all_yosys_asic_synth_script, all_std_cells_libraries, all_main_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder, testbench_folder)
            generate_all_simulation_simple_synthesized_design(all_yosys_simple_synth_script, all_main_synthesis_options, all_synthesis_extra_parameters, synthesis_output_folder, testbench_folder)
        else:
            print(help_string)