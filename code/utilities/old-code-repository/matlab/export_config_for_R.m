%% export_config_for_R.m
% This script prepares a cleaned version of the MATLAB config struct for 
% export as a JSON file to be used in R/Python analysis scripts.
%
% It removes function handles and non-serializable fields, replaces
% complex structs with simple descriptive strings (e.g., decode_method),
% and saves the result as a JSON file.

clc;
clear;
close all;

%% Set project paths
% Use '~' for home directory on Mac/Linux; update paths if on Windows
project_root = '~/Documents/PhD/Project';
addpath(genpath(project_root));

project_path = '~/Documents/PhD/Project/viewpoint'; % Optional, depending on your structure

%% Load MATLAB config struct
config_file = @decoding_config;
config = config_file();

%% Clean up config for JSON export
% Remove fields with function handles or complex objects not serializable
if isfield(config, 'classifier')
    config = rmfield(config, 'classifier');
end

% Remove function handle related fields inside decode_type
fields_to_remove = {'target_func', 'use_custom_targets_chunks', 'custom_target_chunk_func'};
config.decode_type = rmfield(config.decode_type, fields_to_remove);

%% Create a simple 'decode_method' field from 'chunk_func'
for i = 1:numel(config.decode_type)
    chunk_func = config.decode_type(i).chunk_func;
    
    if isstruct(chunk_func)
        % Get all field names of the struct as a cell array
        fnames = fieldnames(chunk_func);
        config.decode_type(i).decode_method = fnames;  % Save all field names as cell array
        
    elseif ischar(chunk_func)
        % If char array, save as a cell array with one string for consistency
        config.decode_type(i).decode_method = {chunk_func};
        
    else
        % For unexpected types, assign empty cell
        config.decode_type(i).decode_method = {};
    end
end


% Remove the original complex 'chunk_func' field after processing
config.decode_type = rmfield(config.decode_type, 'chunk_func');

%% Add any additional fields or modify for clarity
config.is_infant = true;   % Example additional field
config.folder = 'infants'; % Example additional field

%% Export the cleaned config as JSON
output_path = '~/Downloads/group_analysis_config.json'; % Adjust as needed

json_text = jsonencode(config);

fid = fopen(output_path, 'w');
if fid == -1
    error('Cannot open file for writing: %s', output_path);
end
fwrite(fid, json_text, 'char');
fclose(fid);

fprintf('Config exported successfully to %s\n', output_path);
