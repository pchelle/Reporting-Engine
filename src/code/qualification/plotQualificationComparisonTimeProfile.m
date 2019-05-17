function plotQualificationComparisonTimeProfile(WSettings,figureHandle,CompTimeProfile,ObservedDataSets,SimulationMappings, Curves, AxesOptions, PlotSettings)
%PLOTCOMPARISONQUALIFICATIONTIMEPROFILE Plots the time profile of a population in comparison to a reference population
%
% plotQualificationTimeProfile(WSettings,figureHandle,SimTL,DataTP, Curves, AxesOptions,PlotSettings)
%
% Inputs:
%       WSettings (structure)    definition of properties used in all
%                   workflow functions see GETDEFAULTWORKFLOWSETTINGS
%   figureHandle ( handle) handle of figure
%   TimeProfile (structure) with Project and Simulation to be mapped
%   ObservedDataSets (structure) of all loaded observed data
%   SimulationMappings (structure) to mapping linking simulations to there path
%   Curves (structure) to internal path of simulations or observations
%   AxesOptions (structure) to set plot options
%   PlotSettings (structure) to set plot options
%
% Open Systems Pharmacology Suite;  http://open-systems-pharmacology.org

%---------------------------------------------

% Create figure with first setting from WSettings using getReportFigure
% To be updated using the Configuration plan Settings as optional arguments

ax = getReportFigureQP(WSettings,1,1,figureHandle,PlotSettings);

[xAxesOptions, yAxesOptions, yyAxesOptions] = setFigureOptions(AxesOptions);

%Initialize legend label
legendLabels={};

for i=1:length(Curves)
    
    % Load the mapped Time Profile Simulation Results
    [csvSimFile, xmlfile] = getSimFile(Curves(i), SimulationMappings);
    SimResult = loadSimResultcsv(csvSimFile, Curves(i));
    
    % Initialize simulation, and get Molecular Weight in g/mol for correct use of getUnitFactor
    initSimulation(xmlfile,'none');
    MW = getMolecularWeightForPath(Curves(i).Output);
    
    if ~isfield(Curves(i), 'EndTime') || isempty(Curves(i).EndTime)
        Curves(i).EndTime = Curves(i).StartTime + CompTimeProfile.SimulationDuration;
    end
    
    % For simulations: Get the right simulation curve
    [p_handle_sim, legLabel_sim] = testandplotSimResults(Curves(i), SimResult, MW, xAxesOptions, yAxesOptions, yyAxesOptions);
    if isempty(p_handle_sim)
        ME = MException('plotQualificationComparisonTimeProfile:notFoundInPath', ...
            'In Mapping %d, Ouptut %s was not found', i, Curves(i).Output);
        throw(ME);
    end
    [p_handle_obs, legLabel_obs] = testandplotObservations(Curves(i), ObservedDataSets, MW, xAxesOptions, yAxesOptions, yyAxesOptions);
    if isempty(p_handle_obs)
        ME = MException('plotQualificationComparisonTimeProfile:notFoundInPath', ...
            'In Mapping %d, ObservedData %s was not found', i, Curves(i).ObservedData);
        throw(ME);
    end
    legendLabels=[legendLabels legLabel_sim legLabel_obs];
end
legend(legendLabels, 'Location', 'northoutside');
%legend('off')

% ------------------------- Auxiliary functions -------------------------
% For simulations: Get the right simulation curve with right unit
function [p_handle, legendLabels] = testandplotSimResults(Curves, SimResult, MW, xAxesOptions, yAxesOptions, yyAxesOptions)

% Initialize output as empty. If return an empty plot handle, the path was
% not found in the loop
dimensionList=getDimensions;
p_handle=[];
legendLabels=[];

for j = 1:length(SimResult.outputPathList)
    findPathOutput = contains(SimResult.outputPathList{j}, Curves.Output);
    if findPathOutput
        legendLabels=Curves.Caption;
        
        if isfield(Curves, 'yAxisType')
            if strcmp(Curves.yAxisType, 'Y2')
                yyaxis right
                YDimension=dimensionList{strContains(yyAxesOptions.Dimension, dimensionList)};
                Yfactor=getUnitFactor(SimResult.outputUnit{j},yyAxesOptions.Unit,YDimension, 'MW',MW);
                
                % Convert units to reference unit
                XDimension=dimensionList{strContains(xAxesOptions.Dimension, dimensionList)};
                Xfactor=getUnitFactor(SimResult.timeUnit,xAxesOptions.Unit,XDimension);
                
                SimTime = (SimResult.time.*Xfactor >= Curves.StartTime &  SimResult.time.*Xfactor <= Curves.EndTime);
                disp(max(SimTime));
                FinalTime = SimResult.time(SimTime).*Xfactor;
                FinalSim = SimResult.y{j}.*Yfactor;
                FinalSim = FinalSim(SimTime);
                
                p_handle = plot(FinalTime, FinalSim);
                legendLabels=sprintf('%s Simulated Data', Curves.Caption);
                CurveOptions.Color = Curves.Color;
                CurveOptions.LineStyle='Solid';
                setCurveOptions(p_handle, CurveOptions);
                yyaxis left
            end
        else
            
            YDimension=dimensionList{strContains(yAxesOptions.Dimension, dimensionList)};
            Yfactor=getUnitFactor(SimResult.outputUnit{j},yAxesOptions.Unit,YDimension, 'MW',MW);
            
            % Convert units to reference unit
            XDimension=dimensionList{strContains(xAxesOptions.Dimension, dimensionList)};
            Xfactor=getUnitFactor(SimResult.timeUnit,xAxesOptions.Unit,XDimension);
            
            SimTime = (SimResult.time.*Xfactor >= Curves.StartTime &  SimResult.time.*Xfactor <= Curves.EndTime);
            FinalTime = SimResult.time(SimTime).*Xfactor;
            FinalSim = SimResult.y{j}.*Yfactor;
            FinalSim = FinalSim(SimTime);
            
            p_handle = plot(FinalTime, FinalSim);
            
            legendLabels=sprintf('%s Simulated Data', Curves.Caption);
            CurveOptions.Color = Curves.Color;
            CurveOptions.LineStyle='Solid';
            setCurveOptions(p_handle, CurveOptions);
            break
            
        end
    end
end

% For observation: Get the right observation curve with right unit
function [p_handle, legendLabels] = testandplotObservations(Curves, ObservedDataSets, MW, xAxesOptions, yAxesOptions, yyAxesOptions)

% Initialize output as empty. If return an empty plot handle, the path was
% not found in the loop
dimensionList=getDimensions;
p_handle=[];
legendLabels=[];

for j = 1:length(ObservedDataSets)
    findPathOutput = contains(Curves.ObservedData,ObservedDataSets(j).Id);
    if findPathOutput
        
        if isfield(Curves, 'yAxisType')
            if strcmp(Curves.yAxisType, 'Y2')
                yyaxis right
                YDimension=dimensionList{strContains(yyAxesOptions.Dimension, dimensionList)};
                Yfactor=getUnitFactor(ObservedDataSets(j).outputUnit{j},yyAxesOptions.Unit,YDimension, 'MW',MW);
                
                % Convert units to reference unit
                XDimension=dimensionList{strContains(xAxesOptions.Dimension, dimensionList)};
                Xfactor=getUnitFactor(ObservedDataSets(j).timeUnit,xAxesOptions.Unit,XDimension);
                
                p_handle = plot(ObservedDataSets(j).time.*Xfactor, ObservedDataSets(j).y{1}.*Yfactor);
                
                legendLabels=sprintf('%s Observed Data', Curves.Caption);
                CurveOptions.Color = Curves.Color;
                CurveOptions.Symbol = Curves.Symbol;
                CurveOptions.LineStyle = 'none';
                setCurveOptions(p_handle, CurveOptions);
                yyaxis left
                break
            end
        else
            
            YDimension=dimensionList{strContains(yAxesOptions.Dimension, dimensionList)};
            Yfactor=getUnitFactor(ObservedDataSets(j).outputUnit{1},yAxesOptions.Unit,YDimension, 'MW',MW);
            
            % Convert units to reference unit
            XDimension=dimensionList{strContains(xAxesOptions.Dimension, dimensionList)};
            Xfactor=getUnitFactor(ObservedDataSets(j).timeUnit,xAxesOptions.Unit,XDimension);
            
            p_handle = plot(ObservedDataSets(j).time.*Xfactor, ObservedDataSets(j).y{1}.*Yfactor);
            
            legendLabels=sprintf('%s Observed Data', Curves.Caption);
            CurveOptions.Color = Curves.Color;
            CurveOptions.Symbol = Curves.Symbol;
            CurveOptions.LineStyle = 'none';
            setCurveOptions(p_handle, CurveOptions);
            break
        end
        break
    end
end