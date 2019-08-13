%% Start EEGLAB
clear;
close all;
try
    disp('Starting EEGLAB.');
    eeglab;
catch
    error('EEGLAB not found. Please set path to EEGLAB execution script.');
end

%% Load EEG Data
[dataFile, dataDirectory] = uigetfile('*.*', 'MultiSelect', 'on');
if (~iscell(dataFile))
    dataFile = {dataFile};
end
dataFile = sort(dataFile);
datasetNumber = length(dataFile);
datasetName = cell(datasetNumber, 1);
for n = 1:datasetNumber
    name = strsplit(dataFile{n}, '.');
    datasetName(n) = name(1);
end
datasetName = inputdlg(dataFile, 'Enter dataset name', 1, datasetName);

for n = 1:datasetNumber
    dataFilePath = fullfile(dataDirectory, dataFile{n});
    assert(exist(dataFilePath, 'file') == 2, 'No file input.');

    EEG = pop_biosig(dataFilePath);
    EEG.setname = datasetName{n};
    EEG = pop_select(EEG, 'channel', {'A1' 'A2' 'A3' 'A4' 'A5' 'A6' 'A7' 'A8' 'A9' 'A10' 'A11' 'A12' 'A13' 'A14' 'A15' 'A16' 'A17' 'A18' 'A19' 'A20' 'A21' 'A22' 'A23' 'A24' 'A25' 'A26' 'A27' 'A28' 'A29' 'A30' 'A31' 'A32' 'B1' 'B2' 'B3' 'B4' 'B5' 'B6' 'B7' 'B8' 'B9' 'B10' 'B11' 'B12' 'B13' 'B14' 'B15' 'B16' 'B17' 'B18' 'B19' 'B20' 'B21' 'B22' 'B23' 'B24' 'B25' 'B26' 'B27' 'B28' 'B29' 'B30' 'B31' 'B32' 'EXG1' 'EXG2'});
    EEG = eeg_checkset(EEG);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    eeglab redraw
end

% Extract marker information
disp('Extracting marker information...');

triggerBitLength = 3;
markerList = unique([ALLEEG(1).event.type]);
markerNumber = length(markerList);
for dataset = 1:datasetNumber
    % Convert binary marker into decimal marker
    for n = 1:length(ALLEEG(dataset).event)
        bin = (dec2bin(ALLEEG(dataset).event(n).type) - '0');
        bin = bin(end - triggerBitLength + 1:end);
        marker = bi2de(bin, 'right-msb');
        ALLEEG(dataset).event(n).marker = marker;
    end

    % Extract unique markers
    markerList = unique([ALLEEG(dataset).event.marker]);
    assert(markerNumber == length(markerList), 'Number of markers mismatched.');
    markerNumber = length(markerList);
    markerNameList = cell(1, markerNumber);
    for n = 1:markerNumber
        markerNameList(1, n) = strcat({'Marker '}, num2str(markerList(n)));
    end
end

defaultLabelList = {'Onset', 'Rest', 'Stim1', 'Stim2', 'Stim3', 'ignore'};
labelList = inputdlg(markerNameList, 'Assign labels to markers', 1, defaultLabelList);

% Assign readable labels to markers
for dataset = 1:datasetNumber
    for n = 1:length(ALLEEG(dataset).event)
        ALLEEG(dataset).event(n).type = char(labelList{find(markerList == ALLEEG(dataset).event(n).marker)});
    end
end

% Merge all dataset
if (datasetNumber > 1)
    EEG = pop_mergeset(ALLEEG, 1:datasetNumber, 0);
    EEG = eeg_checkset(EEG);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
    eeglab redraw;
end

mergedDatasetNumber = CURRENTSET;

%% Apply filter to raw data
lowerCutOff = 1;
higherCutOff = 30;
EEG = pop_eegfiltnew(ALLEEG(mergedDatasetNumber), lowerCutOff, higherCutOff, 13518, 0, [], 1);
EEG.setname = char(strcat({'Filtered '}, EEG.setname));
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'gui', 'off'); 
eeglab redraw

filteredDatasetNumber = CURRENTSET;

%% Re-reference the filtered data
EEG = pop_reref(ALLEEG(filteredDatasetNumber), [65 66]);
EEG.setname = char(strcat({'Re-ref '}, EEG.setname));
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'gui', 'off'); 
eeglab redraw

reRefedDatasetNumber = CURRENTSET;

%% Re-sampling to 512 Hz
EEG = pop_resample(ALLEEG(reRefedDatasetNumber), 512);
EEG.setname = char(strcat({'512 Hz '}, EEG.setname));
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'gui', 'off');
eeglab redraw

downSampledDatasetNumber = CURRENTSET;

%% Extact each epochs and add channel locations to each datasets
for marker = 1:markerNumber
    if (strcmp(labelList(marker), 'ignore') == 0)
        EEG = pop_epoch(ALLEEG(downSampledDatasetNumber), labelList(marker), [-1  2], 'newname', char(strcat(labelList(marker), {' epochs'})), 'epochinfo', 'yes');
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');  
        EEG = eeg_checkset( EEG );
        EEG = pop_rmbase( EEG, [-1000     0]);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'overwrite','on','gui','off');
        EEG=pop_chanedit(EEG, 'lookup','standard_1005.elc','load',{'Standard-10-20-Cap64-Provisional.locs' 'filetype' 'autodetect'});
        [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
        EEG = eeg_checkset( EEG );
    end
end
eeglab redraw
