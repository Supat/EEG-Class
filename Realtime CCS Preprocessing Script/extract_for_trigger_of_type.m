function [time_point] = extract_for_trigger_of_type(xdf_path, trigger_type, signal_type)
%extract_xdf_trigger Summary of this function goes here
%   Detailed explanation goes here

disp('Reading XDF file...');
LSL_data = load_xdf(xdf_path);

if nargin == 1
    signal_type_str = cell(1, length(LSL_data));
    for i = 1:length(LSL_data)
        signal_type_str{i} = LSL_data{i}.info.type;
    end
    [selected_signal, ok] = listdlg('PromptString', 'Select signal type:', 'SelectionMode', 'single', 'ListSize', [180 120], 'ListString', signal_type_str);
    [selected_trigger, ok] = listdlg('PromptString', 'Select trigger signal:', 'SelectionMode', 'single', 'ListSize', [180 120], 'ListString', signal_type_str);
    signal_type = LSL_data{selected_signal}.info.type;
    trigger_type = LSL_data{selected_trigger}.info.type;
end

for i = 1:length(LSL_data)
    if strcmp(LSL_data{i}.info.type, signal_type)
        EEG = LSL_data{i};
    elseif strcmp(LSL_data{i}.info.type, trigger_type)
        Trigger = LSL_data{i};
    end
end

time_point = zeros(length(Trigger.time_series), 3);

fprintf(1, 'Trigger count: %d\n', length(Trigger.time_series));
disp('Extracting triggers timepoint...');
for i = 1:length(Trigger.time_series)
    fprintf(1, '%d ', i);
    distance = abs(EEG.time_stamps-Trigger.time_stamps(i));
    time_point(i, 1) = i;
    time_point(i, 2) = find(distance==min(distance));
    time_point(i, 3) = Trigger.time_series(i);
end
fprintf(1, '\n');

