
tbl = readtable('data.xlsx');

chunkSize = 365; % yearly data
totalRows = height(tbl);%1491 data loaded
numIntervals = 96; % 24 hours has 96 intervals of 15 minutes
numChunks = ceil(totalRows / chunkSize); % Number of chunks

monthlyAveragesAllChunks = cell(numChunks, 1);
chunkIndices = cell(numChunks, 1);

startTime = datetime(2023, 1, 1, 0, 0, 0); %  midnight jan 1/23
timeIntervals = startTime + minutes(15 * (0:numIntervals-1)); 
timeStrings = cellstr(datestr(timeIntervals, 'HH:MM')); % Formatting intervals as strings


for chunkIdx = 1:numChunks
    startIdx = (chunkIdx - 1) * chunkSize + 1;
    endIdx = min(chunkIdx * chunkSize, totalRows);
    
    % extract
    chunk = tbl(startIdx:endIdx, :);
    
    if any(startsWith(chunk.Properties.VariableNames, 'data_value'))
        % extract column
        dataColumnNames = startsWith(chunk.Properties.VariableNames, 'data_value');
        dataValues = table2array(chunk(:, dataColumnNames));
        
        % convert into date-time
        if isdatetime(chunk.data_date) == false
            chunk.data_date = datetime(chunk.data_date);
        end
        chunk.Month = month(chunk.data_date);
        
        % initialize
        monthlyAverages = NaN(12, numIntervals);
        
        %15 min avg
        for m = 1:12
            monthRows = chunk.Month == m;
            if any(monthRows)
                monthlyData = dataValues(monthRows, :);
                monthlyAverages(m, :) = mean(monthlyData, 1); % Mean across days for each interval
            end
        end
        
     


        monthlyAveragesAllChunks{chunkIdx} = monthlyAverages;
        chunkIndices{chunkIdx} = [startIdx, endIdx];
    end
end


for chunkIdx = 1:numChunks
    monthlyAverages = monthlyAveragesAllChunks{chunkIdx};
    chunkRange = chunkIndices{chunkIdx};
    
    monthNames = month(datetime(2024, 1:12, 1), 'name'); % 'name'    gives full month names
    
    assert(numel(timeStrings) == numIntervals, 'error in number of time intervals and columns in data.');
    assert(numel(monthNames) == size(monthlyAverages, 1), 'error in number of months and rows in data.');
    
    % Create heatmap for each chunk
    figure;
    h = heatmap(timeStrings, monthNames, monthlyAverages); % x, y, value
    h.Title = sprintf('chunk # %d: Data values for month and days (%d to %d)', chunkIdx, chunkRange(1), chunkRange(2));
    h.XLabel = 'Time interval(15min)'; 
    h.YLabel = 'Month'; 
    
    % Perform k-means clustering on the data within the chunk
    dataValues = table2array(tbl(chunkRange(1):chunkRange(2), dataColumnNames));
    k = 2; % Number of clusters
    [idx, C] = kmeans(dataValues, k);
    
    % Plot k-means clustering results for the chunk
    figure;
    hold on;
    colors = lines(k);
    
    for clusterIdx = 1:k
        clusterMonths = find(idx == clusterIdx);
        clusterData = dataValues(clusterMonths, :);
        plot(mean(clusterData, 1), 'Color', colors(clusterIdx, :), 'LineWidth', 2);
    end
    
    xlabel('Time interval(15min)');
    ylabel('average');
    title(sprintf('chunk # %d: k-means clustering of values (%d to %d)', chunkIdx, chunkRange(1), chunkRange(2)));
    legend(arrayfun(@(x) sprintf('cluster %d', x), 1:k, 'UniformOutput', false), 'Location', 'Best');
    hold off;
end

% Calinski-Harabascz
dataValues = table2array(tbl(:, dataColumnNames));
evalResults = evalclusters(dataValues, 'kmeans', 'CalinskiHarabasz', 'KList', 1:10); % Assume k is between 1-10


%VISUALIZATION%
%optimal number of clusters
figure;
plot(evalResults);
xlabel('Number of Clusters (k)');
ylabel('Calinski-Harabasz Index');
title('Calinski-Harabasz Index vs. Number of Clusters');
optimalK = evalResults.OptimalK;
disp(['Optimal number of clusters (k): ', num2str(optimalK)]);
