%% 任务四：储能选址定容与交流潮流校核
% 储能231 梁宏熙，学号206231315。依据第二周模板与任务四课件完成。
% 在本人的纯负荷馈线中决定是否建站、位置、成对功率/能量档位和24小时运行计划。
% 本文件与同名MLX配套；完整MILP建模和数值校验位于week2_solve.m。

clear; clc; close all;
work_dir=fileparts(mfilename('fullpath')); addpath(work_dir);
case_dir=week2_environment(work_dir);
Stu_ID=206231315;

%% 1. 规划模型与参数
% 算例：城市23节点，alpha=1+0.002*15=1.03，候选节点[4,9,14]，不接光伏。
% 额定功率/能量成对取[1,1]至[5,5] MW/MWh；SoC范围[0.20,0.80]，初末为0.50。
% 充/放电效率0.90/0.95；线性模型电压范围[0.96,1.05] p.u.。
% cP=8e4元/MW，cE=5.5e5元/MWh，年运维2e5元/(MW·年)，寿命20年、贴现率5%。
% 目标：投资等年值 + 年运维费用 + 365天典型日购电费用。
% 使用z、w二进制规划变量，u为充放电互斥二进制变量；SoC与功率为连续变量。
% 四条大M约束使delta=w*SoC精确成立，能量平衡因此成为线性等式。
% LinDistFlow忽略支路网损，事后通过MATPOWER交流潮流复核，而不直接等同两种费用口径。

V_min_Lin=0.960; energy_cost_multiplier=1;
Base=week2_solve(Stu_ID,case_dir,V_min_Lin,energy_cost_multiplier);
assert(Base.Feasible,'基准规划求解失败：%s',Base.Info);
assert(Base.Check.Passed && Base.Check.ACVoltagePassed,'基准规划或交流电压未通过校核。');
disp(Base.Configuration);
CostComponents=table(Base.Cost.InvestmentAnnual,Base.Cost.MaintenanceAnnual,...
    Base.Cost.GridAnnual,Base.Cost.TotalAnnual,Base.Cost.ACTotalAnnual,...
    'VariableNames',{'Investment_YuanPerYear','Maintenance_YuanPerYear',...
    'LinearGrid_YuanPerYear','ModelTotal_YuanPerYear','ACActualTotal_YuanPerYear'});
disp(CostComponents);

%% 2. 全网24小时交流校核
% 无储能与配置后采用相同负荷、相同逐时基准；每小时分别检查交流潮流收敛。
% 交流运行范围必须在[0.95,1.05] p.u.，不能只检查某一个节点或某一个时段。
ACCheck=table(Base.MinBaseVoltage,Base.MinLinearVoltage,Base.MinACVoltage,...
    Base.MaxACVoltage,Base.MaxVoltageError,Base.LossBenefitAnnual,...
    Base.Check.ACConverged,Base.Check.ACVoltagePassed,...
    'VariableNames',{'MinBaseVoltage','MinLinearVoltage','MinACVoltage','MaxACVoltage',...
    'MaxVoltageError','LossBenefit_YuanPerYear','AllACConverged','ACVoltagePassed'});
disp(ACCheck);
disp(struct2table(Base.Check));

%% 3. 大M法手算验证：SoC=0.65
% w=0：前两条给出0<=delta<=0；后两条给出-0.15<=delta<=0.45，故delta=0。
% w=1：前两条给出0.20<=delta<=0.80；后两条给出0.65<=delta<=0.65，故delta=0.65。
% 两种二进制状态均满足delta=w*SoC；不以任意巨大常数替代物理上下界。
BigM=table([0;1],[0;0.20],[0;0.80],[-0.15;0.65],[0.45;0.65],[0;0.65],...
    'VariableNames',{'w','Bound1_Lower','Bound2_Upper','Bound3_Lower','Bound4_Upper','ExactDelta'});
disp(BigM);

%% 4. 投资成本和电压下限灵敏度
% 每项只改变一个参数，其余条件与基准完全相同。
% 不可行场景如实保留；不会放宽约束或改用课件示例数字替代本人结果。
settings=[0.96 0.5;0.96 1;0.96 1.5;0.96 2;0.95 1;0.965 1];
Studies=cell(size(settings,1),1);
for n=1:size(settings,1)
    if all(abs(settings(n,:)-[0.96,1])<1e-12)
        Studies{n}=Base;
    else
        Studies{n}=week2_solve(Stu_ID,case_dir,settings(n,1),settings(n,2));
    end
    save(fullfile(work_dir,'Week2_study_checkpoint.mat'),'Base','Studies');
end
Sensitivity=week2_sensitivity_table(Studies);
disp(Sensitivity);

%% 5. 标准化评测文件
% 沿用模板规定的Result变量名及六个字段，不增加或重命名字段。
% Opt_Sites保存候选节点序号，实际节点为Base.CandidateBuses(Result.Opt_Sites)。
Result.StuID=Stu_ID;
Result.Obj_Value=Base.Cost.TotalAnnual;
Result.Opt_Sites=find(Base.Z==1);
Result.Opt_P_rated=Base.RatedPowerMW;
Result.Opt_E_rated=Base.RatedEnergyMWh;
Result.Max_V_Err=Base.MaxVoltageError;
save(fullfile(work_dir,'result_summary.mat'),'Result');
save(fullfile(work_dir,'Week2_results_206231315.mat'),'Base','Studies','Sensitivity','BigM');
writetable(Base.Configuration,fullfile(work_dir,'Week2_Configuration_206231315.csv'));
writetable(Sensitivity,fullfile(work_dir,'Week2_Sensitivity_206231315.csv'));
Summary=struct('StudentID',Stu_ID,'Name','梁宏熙','Class','储能231','Base',Base,...
    'Sensitivity',table2struct(Sensitivity),'BigM',table2struct(BigM));
fid=fopen(fullfile(work_dir,'Week2_summary_206231315.json'),'w','n','UTF-8');
assert(fid~=-1,'无法保存结果摘要。'); fprintf(fid,'%s',jsonencode(Summary,'PrettyPrint',true)); fclose(fid);

%% 6. 规划前后电压、配置费用、运行曲线与灵敏度图
% 白底600dpi PNG、矢量PDF及可编辑FIG；绘图不依赖R2025a的theme函数。
Figures=week2_figures(work_dir,Base,Sensitivity);
fprintf('\n任务四已完成：模型年费用 %.6f 万元，交流电压[%.8f, %.8f] p.u.。\n',...
    Base.Cost.TotalAnnual/1e4,Base.MinACVoltage,Base.MaxACVoltage);
fprintf('标准结果文件：%s\n',fullfile(work_dir,'result_summary.mat'));
