RDM = cell(14,14);
nIter = 0;

for i = 1:14
    for j = i+1:14

        if i == j
            % Avoids computing the lower half/ diagonal of the matrix
            continue
        else

            if ismember(i, [2, 3, 4, 5, 7, 8, 9])
                a = 'animate';
            else 
                a = 'inanimate';
            end

            if ismember(j, [2, 3, 4, 5, 7, 8, 9])
                b = 'animate';
            else
                b = 'inanimate';
            end
            
            if strcmp(a,b)
                RDM{i, j} = a;
                RDM{j,i} = a;
            else
                RDM{i, j} = {a,b};
                RDM{j,i} = {a,b};
            end

        end
        % Increment iteration counter
        nIter = nIter + 1;
    end
end

% Define the new order: animate indices first, then inanimate
animate_indices = [2, 3, 4, 5, 7, 8, 9];
inanimate_indices = [1, 6, 10, 11, 12, 13, 14];

% Create the permutation order
new_order = [animate_indices, inanimate_indices];

% Rearrange both rows and columns of RDM
RDM_rearranged = RDM(new_order, new_order);