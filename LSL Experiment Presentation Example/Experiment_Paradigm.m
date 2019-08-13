function Experiment_Paradigm()

close all
clc

warning off backtrace
c
%% Constants
TRIG_ONSET = 1;
TRIG_REST = 2;
TRIG_STIM_1 = 3;
TRIG_STIM_2 = 4;
TRIG_STIM_3 = 5;
TRIG_BLINK = 6;

%% Initial Parameters
numberOfBlocks = 25;
stimulusSequence = [1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3];
onsetDuration = 2;
stimulusDuration = 2;
restingDuration = 2;

stimulusFigureID = 1;

log = [];

%% LSL Connection
LSLAvailable = false;
try
    lib = lsl_loadlib();
    if ~(isempty(lib))
        info = lsl_streaminfo(lib, 'Stimulus PC', 'Trigger', 1, 0, 'cf_float32', 'TRG1');
        outlet = lsl_outlet(info);
    end
    LSLAvailable = true;
    fprintf('Using LSL.\n');
    fprintf('Make sure to update Lab Recorder before continue.\n');
catch e
    warning('LSL Error.');
end

%% DAQ Connection
DAQToolBoxAvailable = false;
isLegacyToolbox = false;
if (~LSLAvailable)
    
    % Session-based
    try
        triggerDevice = daq.getDevices;
        triggerSession = daq.createSession('ni');
        addDigitalChannel(triggerSession, triggerDevice.ID, 'Port1/Line0:2', 'OutputOnly');
        sendTrigger(7);
        DAQToolBoxAvailable = true;
        isLegacyToolbox = false;
        fprintf('Using session-based DAQ toolbox.\n');
    catch e
        warning('Session-based DAQ Toolbox Error.');
        if (strcmp(e.identifier, 'MATLAB:undefinedVarOrClass'))
            warning('Session-based DAQ toolbox not found.');
        else
            warning('%s error occured while trying to connect to trigger device.', e.identifier);
        end
        DAQToolBoxAvailable = false;
    end

    % Legacy
    if (~DAQToolBoxAvailable)
        try
            DAQVender = 'nidaq';
            triggerDevice = daqhwinfo(DAQVender);
            DAQDeviceID = triggerDevice.InstalledBoardIds{1};
            triggerIO = digitalio(DAQVender, DAQDeviceID);
            addline(triggerIO, 0:7, 1.0, 'out');
            putvalue(triggerIO, 255);
            DAQToolBoxAvailable = true;
            isLegacyToolbox = true;
            fprintf('Using legacy DAQ toolbox.\n');
        catch e
            warning('Legacy DAQ Toolbox Error.');
            if (strcmp(e.identifier, 'MATLAB:UndefinedFunction'))
                warning('Legacy DAQ toolbox not found.');
            else
                warning('%s error occured while trying to connect to trigger device.', e.identifier);
            end
            DAQToolBoxAvailable = false;
            isLegacyToolbox = false;
        end
    end
    if (~DAQToolBoxAvailable)
        warning('No trigger device found.');
    end
end

%% Setup Display
stimulusFigure = figure(stimulusFigureID);
set(stimulusFigure,'units','normalized','outerposition',[0 0 1 1])
set(gca,'Position',get(gca,'OuterPosition'));

%% Commencing Prompt
fprintf('Move figure window into stimulus display.\n')
if (~DAQToolBoxAvailable && ~LSLAvailable)
    fprintf('Press any key to continue in non-trigger mode>>\n');
else
    fprintf('Press any key to start data acquisition>>\n');
end
pause;

if (LSLAvailable)
    try
        sendTrigger(0);
    catch
        warning('LSL Connection error.');
    end
end



%% Random Stimulus Sequence
randomizedStimuliSequence = zeros(1,numberOfBlocks);
randomSequence = randperm(numberOfBlocks);
for i = 1:numberOfBlocks
    randomizedStimuliSequence(1,i) = stimulusSequence(1, randomSequence(1,i));
end

%% Import Stimulus Image
flex_high = imread('flex_high.png');
ext_high = imread('ext_high.png');
still = imread('still.png');
blink = imread('blink.png');

flex_high = imresize(flex_high,1, 'nearest');
ext_high = imresize(ext_high, 1, 'nearest');
still = imresize(still, 1, 'nearest');
blink = imresize(blink, 1, 'nearest');
get(0,'ScreenSize');

%% Start Marker

sendTrigger(TRIG_REST);
figure(stimulusFigureID),imshow(blink);
drawnow;
pause(stimulusDuration);


for block = 1:numberOfBlocks
    fprintf ('Block: %d, Stimulus: %d\n', block, randomizedStimuliSequence(1,block));
    
    %% Resting Phase
    sendTrigger(TRIG_REST);
    figure(stimulusFigureID),imshow(blink)
    drawnow;
    pause(restingDuration);
    
    
    %% Stimulus Onset
    sendTrigger(TRIG_ONSET);
    figure(stimulusFigureID),imshow(still)
    drawnow;
    pause(onsetDuration);
    
    
    %% Stimulus
    switch randomizedStimuliSequence(1,block)
        case 1
            sendTrigger(TRIG_STIM_1);
            figure(stimulusFigureID),imshow(flex_high)
        case 2
            sendTrigger(TRIG_STIM_2);
            figure(stimulusFigureID),imshow(ext_high)
        case 3
            sendTrigger(TRIG_STIM_3);
            figure(stimulusFigureID),imshow(still)
        otherwise
            sendTrigger(TRIG_STIM_3);
            figure(stimulusFigureID),imshow(still)
    end
    drawnow;
    pause(stimulusDuration);    
    
    %% Stimulus Onset
    sendTrigger(TRIG_ONSET);
    figure(stimulusFigureID),imshow(still)
    drawnow;
    pause(onsetDuration);
    
end

%% End Marker
sendTrigger(TRIG_REST);
figure(stimulusFigureID),imshow(blink)
drawnow;
pause(2)
sendTrigger(7);

close(stimulusFigure);

%% Logging
fid = fopen(strcat('log_', datestr(now,'dd-mm-yyyy_HH:MM')), 'wt');
if fid > 0
    for line = 1:length(log)
        fprintf(fid, '%s, %s\n', log{line, :});
    end
end

if (DAQToolBoxAvailable && ~isLegacyToolbox)
    release(triggerSession);
end

clf

%% Internal Functions

    function sendTrigger(value)
        if (LSLAvailable)
            outlet.push_sample(value);
        elseif (DAQToolBoxAvailable)
            if (isLegacyToolbox)
                putvalue(triggerIO, value);
            else
                outputSingleScan(triggerSession, decimalToBinaryVector(value, 3));
            end
        end
        fprintf ('Trigger: %d\n', value);
        log = vertcat(log, {int2str(value), datestr(now,'dd-mm-yyyy HH:MM:SS FFF')});
    end


end
