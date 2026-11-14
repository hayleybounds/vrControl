function [fhandle, runInfo, trialInfo, expInfo] = prepareTrial(rigInfo, hwInfo, expInfo, runInfo, trialInfo, updateWindow)

fhandle =  @operateTrial;

% If the training window was closed, we can't read trial parameters -- end the
% experiment gracefully (data up to the last trial was already saved in trialEnd)
if expInfo.trainingMode && ~isvalid(updateWindow)
    VRmessage = sprintf('Training window closed -- ending experiment for animal %s, on date %s, session %s, after trial %d.',...
        expInfo.animalName, expInfo.dateStr, expInfo.sessionName, runInfo.currTrial);
    fprintf(2, '%s\n', VRmessage);
    VRLogMessage(expInfo, VRmessage);
    runInfo.abort = 1;
    fhandle = @experimentEnd;
    return
end

runInfo.currTrial = runInfo.currTrial + 1;
runInfo.flipIdx = 0; % Counts flips throughout trial to store data in trialInfo
runInfo.roomPosition = max(rigInfo.minimumPosition, expInfo.startPosition(runInfo.currTrial)); % current position (start position, possibly jittered)
runInfo.move2NextTrial = 0;
runInfo.rewardAvailable = 1; % FLAG to determine if reward has been delivered on current trial (set to 0 if delivered)
runInfo.abort = 0; % turns to 1 if user aborts using the escape key
runInfo.inRewardZone = false;
runInfo.rewZoneTimerActive = false;
runInfo.timeInRewardZone = [];
runInfo.vrEnvIdx = expInfo.envIndex(runInfo.currTrial);
runInfo.pdLevel = 0; % always start at 0 because we have a ramp up from 0 indicating the ITI!
runInfo.lickInRewardZone = false; % keep track of behavioral criterion for reward delivery
runInfo.stopInRewardZone = false; % keep track of behavioral criterion for reward delivery

ListenChar(2);

if expInfo.trainingMode
    % Environment length may be changed in the training window, so keep start inside the corridor
    runInfo.roomPosition = max(rigInfo.minimumPosition, min(runInfo.roomPosition, updateWindow.envLength.Value - 1));

    % Set TRIAL values (update each trial)
    trialInfo.trialIdx(runInfo.currTrial) = runInfo.currTrial; % call me crazy
    trialInfo.startTime(runInfo.currTrial) = GetSecs; % time stamp!!!
    trialInfo.startPosition(runInfo.currTrial) = runInfo.roomPosition; % maybe we'll drop the mice in randomly sometimes...
    trialInfo.activeLicking(runInfo.currTrial) = updateWindow.lickRequired.Value;
    trialInfo.activeStopping(runInfo.currTrial) = updateWindow.stopDuration.Value * updateWindow.stopRequired.Value; 
    trialInfo.rewardPosition(runInfo.currTrial) = updateWindow.rewardPosition.Value;
    trialInfo.rewardTolerance(runInfo.currTrial) = updateWindow.rewardTolerance.Value;
    trialInfo.vrEnvIdx(runInfo.currTrial) = updateWindow.envIdx.Value;
    runInfo.vrEnvIdx = updateWindow.envIdx.Value; 
    
    expInfo.roomLength(runInfo.currTrial) = updateWindow.envLength.Value; 
    expInfo.mvmtGain(runInfo.currTrial) = updateWindow.mvmtGain.Value; 
    expInfo.rewardPosition(runInfo.currTrial) = updateWindow.rewardPosition.Value; 
    expInfo.rewardTolerance(runInfo.currTrial) = updateWindow.rewardTolerance.Value; 
    expInfo.activeLick(runInfo.currTrial) = updateWindow.lickRequired.Value; 
    expInfo.activeStop(runInfo.currTrial) = updateWindow.stopDuration.Value * updateWindow.stopRequired.Value;
    if updateWindow.maxTrialDuration.Value > 0
        expInfo.maxDuration = updateWindow.maxTrialDuration.Value; % editable in training window
    else
        updateWindow.maxTrialDuration.Value = expInfo.maxDuration; % reject invalid (<=0) entries
    end
    % ITI is pre-generated (may be randomized) -- show this trial's value in the window
    updateWindow.minimumITI.Value = expInfo.intertrialInterval(runInfo.currTrial);

    
    rewAvailable = rand() < updateWindow.probReward.Value;
    trialInfo.rewardAvailable(runInfo.currTrial) = rewAvailable;
    if ~rewAvailable, runInfo.rewardAvailable = 0; end % make it impossible to get a reward in this trial

    % Check if updateWindow is active and still open, then do update
    updateWindow.setCurrentTrial(runInfo.currTrial);
    updateWindow.setRewardAvailable(1*rewAvailable); 
    updateWindow.valueUpdated(false); % reset to indicate that we've updated everything
    updateWindow.updateTrial(); % Update all features of GUI
else
    % Set TRIAL values (update each trial)
    trialInfo.trialIdx(runInfo.currTrial) = runInfo.currTrial; % call me crazy
    trialInfo.startTime(runInfo.currTrial) = GetSecs; % time stamp!!!
    trialInfo.startPosition(runInfo.currTrial) = runInfo.roomPosition; % maybe we'll drop the mice in randomly sometimes...
    trialInfo.activeLicking(runInfo.currTrial) = expInfo.activeLick(runInfo.currTrial); % possible to make this update, for now it's just always the same
    trialInfo.activeStopping(runInfo.currTrial) = expInfo.activeStop(runInfo.currTrial); % possible to make this update, ...
    trialInfo.rewardPosition(runInfo.currTrial) = expInfo.rewardPosition(runInfo.currTrial);
    trialInfo.rewardTolerance(runInfo.currTrial) = expInfo.rewardTolerance(runInfo.currTrial);
    trialInfo.vrEnvIdx(runInfo.currTrial) = expInfo.envIndex(runInfo.currTrial);

    rewAvailable = rand() < expInfo.probReward(runInfo.currTrial);
    trialInfo.rewardAvailable(runInfo.currTrial) = rewAvailable;
    if ~rewAvailable, runInfo.rewardAvailable = 0; end % make it impossible to get a reward in this trial

    % Check if updateWindow is active and still open, then do update
    if expInfo.useUpdateWindow && isvalid(updateWindow)
        updateWindow.updateTrial(runInfo.currTrial, expInfo, rewAvailable, runInfo.vrEnvs{runInfo.vrEnvIdx}(:,:,:,1));
    end
end

fprintf('TRIAL#:%d/%d, vrEnv:%d, SP:%.1fcm, RP:%.1fcm, AL:%d, AS:%d, MG:%.1f, RewAvailable:%d\n',...
    runInfo.currTrial, length(expInfo.envIndex), runInfo.vrEnvIdx, runInfo.roomPosition, expInfo.rewardPosition(runInfo.currTrial),...
    expInfo.activeLick(runInfo.currTrial),expInfo.activeStop(runInfo.currTrial),...
    expInfo.mvmtGain(runInfo.currTrial),rewAvailable);

if expInfo.trainingMode
    elapsedTrainingTime = seconds(toc(runInfo.trainingTimer));
    elapsedTrainingTime.Format = 'mm:ss'; 
    fprintf('Elapsed Time During Training: %s\n', elapsedTrainingTime);
end

% Perform Trial Initiation sequence
ifi = Screen('GetFlipInterval',hwInfo.screenInfo.windowPtr);
prefRefreshTime = 1/rigInfo.PrefRefreshRate;
waitframes = round(prefRefreshTime / ifi);

% Reset PD signal to 0 before startup ramp
Screen('FillRect', hwInfo.screenInfo.windowPtr,0,hwInfo.photodiodeRect.rect);
vbl = Screen('Flip', hwInfo.screenInfo.windowPtr,0,2);

% Make sure pdSignal reaches 0
pause(0.1);

% Perform startup ramp
numPDTrialInitSamples = 20;
for ns = linspace(0, 1, numPDTrialInitSamples)
    Screen('FillRect', hwInfo.screenInfo.windowPtr, ns*255, hwInfo.photodiodeRect.rect);
    vbl = Screen('Flip', hwInfo.screenInfo.windowPtr,vbl+(waitframes-0.5)*ifi,2);
end

% Wait for desired ITI time
while toc(runInfo.ititimer) < expInfo.intertrialInterval(runInfo.currTrial)
    pause(0.0001) 
end

trialInfo.iti(runInfo.currTrial) =  toc(runInfo.ititimer);


















