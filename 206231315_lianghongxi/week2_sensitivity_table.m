function tab=week2_sensitivity_table(studies)
rows=cell(numel(studies),1);
for n=1:numel(studies)
    d=studies{n};
    row=struct('VminLin',d.VminLin,'EnergyCostMultiplier',d.EnergyCostMultiplier,...
        'Feasible',d.Feasible,'Status',"Unresolved",'Sites',"",'TotalPower_MW',NaN,'TotalEnergy_MWh',NaN,...
        'AnnualCost_Yuan',NaN,'MinACVoltage',NaN,'MaxVoltageError',NaN,...
        'ACVoltagePassed',false,'SolveSeconds',d.SolveSeconds,'Info',string(d.Info));
    if d.Feasible
        row.Status="Optimal";
        if any(d.Z==1), row.Sites=string(mat2str(d.CandidateBuses(d.Z==1)));
        else, row.Sites="[]"; end
        row.TotalPower_MW=sum(d.RatedPowerMW); row.TotalEnergy_MWh=sum(d.RatedEnergyMWh);
        row.AnnualCost_Yuan=d.Cost.TotalAnnual; row.MinACVoltage=d.MinACVoltage;
        row.MaxVoltageError=d.MaxVoltageError; row.ACVoltagePassed=d.Check.ACVoltagePassed;
    elseif d.Problem==1
        row.Status="Infeasible";
    end
    rows{n}=row;
end
tab=struct2table(vertcat(rows{:}));
end
