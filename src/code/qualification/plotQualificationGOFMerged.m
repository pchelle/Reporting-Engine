function  GMFE=plotQualificationGOFMerged(WSettings,figureHandle,Groups,ObservedDataSets,SimulationMappings, AxesOptions, PlotSettings)
% PLOTQUALIFICATIONGOFMERGED plot predcited vs observed and residuals vs time
%
% GMFE=plotQualificationGOFMerged(WSettings,figureHandle,Groups,ObservedDataSets,SimulationMappings, PlotSettings)
%
% Inputs:
%       WSettings (structure)    definition of properties used in all
%                   workflow functions see GETDEFAULTWORKFLOWSETTINGS
%   figureHandle ( handle) handle of figure
%   Groups (structure) with simulated results
%   ObservedDataSets (structure) of all loaded observed data
%   SimulationMappings (structure) to map simulations with observations
%   AxesOptions (structure) to set plot options
%   PlotSettings (structure) to set plot options
%
% Output
%   GMFE (numeric) measure of goodness of fit

% Open Systems Pharmacology Suite;  http://open-systems-pharmacology.org

% Initialize the unity line and the time line of the plot
minX=NaN; maxX=NaN; minY=NaN; maxY=NaN; maxtime=NaN; maxRes=NaN;

% create figure for Obs vs Pred
[ax, fig_handle1] = getReportFigureQP(WSettings,1,1,figureHandle,PlotSettings);
[xAxesOptions, yAxesOptions] = setFigureOptions(AxesOptions.GOFMergedPlotsPredictedVsObserved);

% create figure for Residuals vs time
[ax, fig_handle2] = getReportFigureQP(WSettings,1,1,figureHandle+1,PlotSettings);
[TimeAxesOptions, ResAxesOptions] = setFigureOptions(AxesOptions.GOFMergedPlotsResidualsOverTime);

if ~strcmp(ResAxesOptions.Dimension, 'Dimensionless')
    dimensionList=getDimensions;
    ResDimension=dimensionList{strContains(yAxesOptions.Dimension, dimensionList)};
else
    ResDimension='';
end

% Map for each group the corresponding observations within a same structure
for i=1:length(Groups)
    % Load simulation according to mapping
    for j=1:length(Groups(i))
        
        % Load the mapped GOF Simulation Results
        Simulations = Groups(i).OutputMappings(j);
        [csvSimFile, xmlfile] = getSimFile(Simulations, SimulationMappings);
        SimResult = loadSimResultcsv(csvSimFile, Simulations);
        % Initialize simulation, and get Molecular Weight in g/mol for correct use of getUnitFactor
        initSimulation(xmlfile,'none');
        Compound=Simulations.Project;
        MW = getParameter(sprintf('*|%s|Molecular weight',Compound),1,'parametertype','readonly');
        MWUnit = getParameter(sprintf('*|%s|Molecular weight',Compound),1,'parametertype','readonly', 'property', 'Unit');
        MW = MW.*getUnitFactor(MWUnit, 'g/mol', 'Molecular weight');
        
        % Get the right simulation output to be compared
        [predictedTime, predicted] = testSimResults(Simulations, SimResult, MW, TimeAxesOptions, yAxesOptions);
        
        if isempty(predicted)
            ME = MException('plotQualificationGOFMerged:notFoundInPath', ...
                'Group %d SubGroup %d : %s not found', i, j, Simulations.Output);
            throw(ME);
        end
        
        % Get the right simulation output to be compared
        [ObsTime, Obs] = testObservations(Simulations, ObservedDataSets, MW, TimeAxesOptions, yAxesOptions);
        
        if isempty(Obs)
            ME = MException('plotQualificationGOFMerged:notFoundInPath', ...
                'Group %d SubGroup %d : %s not found', i, j, Simulations.ObservedData);
            throw(ME);
        end
        
        % Get points comparable between obs and pred
        comparable_index= getComparablePredicted(ObsTime , predictedTime);
        
        % Group and save comparable points
        Group(i).dataTP(j).yobs = Obs;
        Group(i).dataTP(j).ypred = predicted(comparable_index);
        Yres = predicted(comparable_index)-Obs;
        if strcmp(ResDimension,'')
            Yres=Yres./Obs;
        else
            Resfactor=getUnitFactor(yAxesOptions.Unit,ResAxesOptions.Unit,ResDimension, 'MW',MW);
            Yres=Yres.*Resfactor;
        end
        Group(i).dataTP(j).yres=Yres;
        Group(i).dataTP(j).time = ObsTime;
        
        % Set the min/max of the axis
        minX=nanmin(min(Obs), minX);
        maxX=nanmax(max(Obs), maxX);
        minY=nanmin(min(predicted(comparable_index)), minY);
        maxY=nanmax(max(predicted(comparable_index)), maxY);
        maxtime=nanmax(max(ObsTime), maxtime);
        maxRes=nanmax(max(abs(Yres)), maxRes);
        
        
    end
end

% -------------------------------------------------------------
% Plot the figures
% Observation vs Prediction Figure
figure(fig_handle1);
plot([0.8*min(minX, minY) 1.2*max(maxX, maxY)], [0.8*min(minX, minY) 1.2*max(maxX, maxY)], '--k', 'Linewidth', 1,'HandleVisibility','off');
axis([0.8*min(minX, minY) 1.2*max(maxX, maxY) 0.8*min(minX, minY) 1.2*max(maxX, maxY)]);

legendLabels={};

% Initialize error for computing GMFE
Error=[];

for i=1:length(Groups)
    
    for j=1:length(Groups(i))
        CurveOptions.Color=Groups(i).OutputMappings(j).Color;
        CurveOptions.Symbol=Groups(i).Symbol;
        CurveOptions.LineStyle='none';
        legendLabels{length(legendLabels)+1}=Groups(i).Caption;
        
        pp=plot(Group(i).dataTP(j).yobs, Group(i).dataTP(j).ypred);
        setCurveOptions(pp, CurveOptions);
        
        Error = [Error log10(Group(i).dataTP(j).ypred)-log10(Group(i).dataTP(j).yobs)];
    end
end
xLabelFinal = getLabelWithUnit('Observations',xAxesOptions.Unit);
yLabelFinal = getLabelWithUnit('Predictions',yAxesOptions.Unit);
xlabel(xLabelFinal); ylabel(yLabelFinal);

GMFE = 10.^(sum(abs(Error))/length(Error));
%legend('off')
legend(legendLabels, 'Location', 'northoutside');

% Residuals vs Time Figure
% create figure for Residuals vs time
figure(fig_handle2);
plot([0 1.2*maxtime], [0 0], '--k', 'Linewidth', 1, 'HandleVisibility','off');
axis([0 1.2*maxtime -1.2*abs(maxRes) 1.2*abs(maxRes)]);

legendLabels={};

for i=1:length(Groups)
    for j=1:length(Groups(i))
        CurveOptions.Color=Groups(i).OutputMappings(j).Color;
        CurveOptions.Symbol=Groups(i).Symbol;
        CurveOptions.LineStyle='none';
        legendLabels{length(legendLabels)+1}=Groups(i).Caption;
        
        pp=plot(Group(i).dataTP(j).time, Group(i).dataTP(j).yres);
        setCurveOptions(pp, CurveOptions);
    end
end
xLabelFinal = getLabelWithUnit('Time',TimeAxesOptions.Unit);
yLabelFinal = getLabelWithUnit('Residuals',ResAxesOptions.Unit);
xlabel(xLabelFinal); ylabel(yLabelFinal);
%legend('off')
legend(legendLabels, 'Location', 'northoutside');

% ---------------- Auxiliary function ------------------------------------

% get comparable time points between observations and simulations
function Index = getComparablePredicted(timeObs, timePred)

timeObs = reshape(timeObs, 1, []);
timePred = reshape(timePred, [], 1);

timeObs2 = repmat(timeObs, length(timePred), 1);
timePred2 = repmat(timePred, 1, length(timeObs));

error = (timeObs2-timePred2).*(timeObs2-timePred2);

[Y, Index] = min(error);


% For simulations: Get the right simulation curve with right unit
function [predictedTime, predicted] = testSimResults(Simulations, SimResult, MW, TimeAxesOptions, yAxesOptions)

% If no path is matched ObsTime will be emtpy
predictedTime=[];
predicted=[];

% Get dimensions for scaling plots
dimensionList=getDimensions;
if ~strcmp(yAxesOptions.Dimension, 'Dimensionless')
    YDimension=dimensionList{strContains(yAxesOptions.Dimension, dimensionList)};
else
    YDimension='Fraction';
end

TimeDimension=dimensionList{strContains(TimeAxesOptions.Dimension, dimensionList)};

for j = 1:length(SimResult.outputPathList)
    
    findPathOutput = strcmp(SimResult.outputPathList{j}, Simulations.Output);
    
    if findPathOutput
        
        % Get the data from simulations
        predictedTime=SimResult.time;
        predicted=SimResult.y{j};
        
        % Get unit factor to convert to reference unit
        Yfactor=getUnitFactor(SimResult.outputUnit{j},yAxesOptions.Unit,YDimension, 'MW',MW);
        Timefactor=getUnitFactor(SimResult.timeUnit,TimeAxesOptions.Unit,TimeDimension);
        
        % Convert units to
        predicted = predicted.*Yfactor;
        predictedTime = predictedTime.*Timefactor;
        break
    end
end

% For observation: Get the right observation curve with right unit
function [ObsTime, Obs] = testObservations(Simulations, ObservedDataSets, MW, TimeAxesOptions, yAxesOptions)

% If no path is matched ObsTime will be emtpy
ObsTime=[];
Obs=[];

dimensionList=getDimensions;

if ~strcmp(yAxesOptions.Dimension, 'Dimensionless')
    YDimension=dimensionList{strContains(yAxesOptions.Dimension, dimensionList)};
else
    YDimension='Fraction';
end

TimeDimension=dimensionList{strContains(TimeAxesOptions.Dimension, dimensionList)};

for j = 1:length(ObservedDataSets)
    
    % Get the right observed data
    findPathOutput = strcmp(ObservedDataSets(j).Id, Simulations.ObservedData);
    if findPathOutput
        
        % Get the first outputPathList, may be modified if more than one
        % Observed data is in the file
        Obs=ObservedDataSets(j).y{1};
        ObsTime=ObservedDataSets(j).time;
        
        % Get unit factor to convert to reference unit
        Yfactor=getUnitFactor(ObservedDataSets(j).outputUnit{1},yAxesOptions.Unit,YDimension, 'MW',MW);
        Timefactor=getUnitFactor(ObservedDataSets(j).timeUnit,TimeAxesOptions.Unit,TimeDimension);
        
        % Convert units to
        Obs = Obs.*Yfactor;
        ObsTime = ObsTime.*Timefactor;
        break
    end
end