function [tf, paths, values] = hasFieldDeep(S, targetField)
% HASFIELDDEEP - Recursively search nested structs/cells for a field name
%
% This function performs a deep recursive search through nested MATLAB
% structures (structs and cells) to find all occurrences of a specified
% field name. It returns the paths to each match and their corresponding values.
%
% Inputs:
%   S           - Input data structure to search
%                 Can be: struct, struct array, cell array, or nested combinations
%   
%   targetField - Field name to search for (char or string)
%                 Example: 'preprocess_func', 'decode_type', 'subjectnr'
%
% Outputs:
%   tf     - Logical flag indicating if any matches were found
%            true if at least one field with targetField name exists
%            false if no matches found
%   
%   paths  - Cell array of strings containing dot-indexed paths to each match
%            Uses MATLAB indexing notation:
%              '.' for struct fields       (e.g., 'cfg.decode_type')
%              '()' for struct array index (e.g., 'cfg.decode_type(2)')
%              '{}' for cell array index   (e.g., 'data{3}')
%   
%   values - Cell array containing the actual values at each matched path
%            Same length as paths; values{i} corresponds to paths{i}
%
% Path Notation Examples:
%   'cfg.decode_type.name'           - Simple nested struct
%   'cfg.decode_type(2).target_func' - Second element in struct array
%   'data{3}.field'                  - Third cell contains a struct
%   'mixed(1).cell{2}.nested'        - Complex nesting
%
% Usage Examples:
%   % Search for a field in a simple struct
%   cfg.decode_type.name = 'category';
%   [found, paths, vals] = hasFieldDeep(cfg, 'name');
%   % found = true
%   % paths = {'cfg.decode_type.name'}
%   % vals = {'category'}
%
%   % Search for a field in nested struct array
%   cfg.decode_type(1).name = 'category';
%   cfg.decode_type(2).name = 'identity';
%   [found, paths, vals] = hasFieldDeep(cfg, 'name');
%   % found = true
%   % paths = {'cfg.decode_type(1).name', 'cfg.decode_type(2).name'}
%   % vals = {'category', 'identity'}
%
%   % Search for non-existent field
%   [found, paths, vals] = hasFieldDeep(cfg, 'nonexistent');
%   % found = false
%   % paths = {}
%   % vals = {}
%
% Notes:
%   - Search is case-sensitive (use strcmpi for case-insensitive)
%   - Uses dynamic array growth with %#ok<AGROW> for flexibility
%   - Does not search into tables or object properties (can be extended)
%   - Handles circular references safely (terminates at primitives)
%
% Author:   [Mahdiyeh Khanbagi]
% Created:  [22/08/2025]
% Modified: [13/10/2025]

%% ===================================================================
%  INPUT VALIDATION
%  ===================================================================

% Convert string to char if necessary (for MATLAB compatibility)
if isstring(targetField)
    targetField = char(targetField);
end

%% ===================================================================
%  INITIALIZE OUTPUT VARIABLES
%  ===================================================================

% Initialize empty cell arrays to store results
paths = {};   % Will store paths like 'S.field1.field2'
values = {};  % Will store corresponding field values

%% ===================================================================
%  BEGIN RECURSIVE SEARCH
%  ===================================================================

% Start recursive traversal from root
% inputname(1) gets the variable name of S as it was passed to the function
% This creates readable paths like 'cfg.field' instead of 'input.field'
visit(S, inputname(1));

% Set return flag based on whether any matches were found
tf = ~isempty(paths);

%% ===================================================================
%  NESTED RECURSIVE FUNCTION
%  ===================================================================

    function visit(x, basePath)
        % VISIT - Recursively traverse a data structure searching for targetField
        %
        % Inputs:
        %   x        - Current node being visited (struct, cell, or primitive)
        %   basePath - Accumulated path string from root to current node
        %
        % This function modifies the outer scope variables: paths, values
        
        % -----------------------------------------------------------------
        % CASE 1: Current node is a STRUCT
        % -----------------------------------------------------------------
        if isstruct(x)
            % Handle struct arrays by iterating through each element
            if numel(x) > 1
                % Struct array: recursively visit each element
                for ii = 1:numel(x)
                    % Use (index) notation for struct array elements
                    visit(x(ii), sprintf('%s(%d)', basePath, ii));
                end
                return  % Exit after handling all array elements
            end
            
            % Single struct: check all fields at current level
            fns = fieldnames(x);
            
            for i = 1:numel(fns)
                fn = fns{i};  % Current field name
                
                % Build path to this field
                childPath = sprintf('%s.%s', basePath, fn);
                
                % --- Check if current field matches target ---
                if strcmp(fn, targetField)
                    % Found a match! Store path and value
                    paths{end+1} = childPath;   %#ok<AGROW>
                    values{end+1} = x.(fn);     %#ok<AGROW>
                end
                
                % --- Recurse into nested containers ---
                % Continue searching in case this field contains more structs/cells
                v = x.(fn);
                if isstruct(v) || iscell(v)
                    visit(v, childPath);
                end
                % Note: Primitives (numbers, strings) are not recursed into
            end
            
        % -----------------------------------------------------------------
        % CASE 2: Current node is a CELL ARRAY
        % -----------------------------------------------------------------
        elseif iscell(x)
            % Iterate through each cell element
            for jj = 1:numel(x)
                % Use {index} notation for cell array elements
                visit(x{jj}, sprintf('%s{%d}', basePath, jj));
            end
            
        % -----------------------------------------------------------------
        % CASE 3: Current node is a PRIMITIVE (number, string, etc.)
        % -----------------------------------------------------------------
        else
            % Base case: primitives don't have fields, so stop recursion
            % This includes: double, char, logical, etc.
            return
        end
        
        % -----------------------------------------------------------------
        % OPTIONAL EXTENSIONS (currently commented out)
        % -----------------------------------------------------------------
        % Could add support for:
        %   - Tables: check variable names with table properties
        %   - Objects: use isprop(x, targetField) for class properties
        %   - Maps/containers: use isKey() for Map objects
        
    end

end