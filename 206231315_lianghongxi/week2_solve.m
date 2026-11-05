function D = week2_solve(Stu_ID,case_dir,VminLin,energy_multiplier)
% 课件任务四：离散配置、大M精确线性化、LinDistFlow MILP 与交流回代。
% 功率 MW，能量 MWh，网络功率 p.u.，费用 元/年。无光伏、无储能无功注入。
yalmip('clear');
XY = mod(Stu_ID,100); X = floor(XY/10); Y = mod(XY,10);
alpha = 1+0.002*XY;
if ismember(Y,[0 1 2 3]), case_name='case_nongcun';
elseif ismember(Y,[4 5 6]), case_name='case_chengshi_A';
else, case_name='case_kaifaqu_A'; end
if ismember(X,[0 1 2]), cand=[4 9 14];
elseif ismember(X,[3 4 5]), cand=[5 11 16];
else, cand=[6 13 17]; end
mpc = loadcase(fullfile(case_dir,[case_name '.m']));
profiles = load(fullfile(case_dir,'profiles_24h.mat'));
T=profiles.T; dt=1; Sbase=mpc.baseMVA;
N=size(mpc.bus,1); Nb=size(mpc.branch,1); Nc=numel(cand);
assert(T==24 && Nb==N-1 && isequal(mpc.bus(:,1),(1:N)'),'需要连续编号的24时段辐射状算例。');
Popt=1:5; Eopt=1:5; K=numel(Popt);
etaCh=0.90; etaDis=0.95; socMin=0.20; socMax=0.80; soc0=0.50;
cP=8e4; cE=5.5e5*energy_multiplier; cOM=2e5; years=20; rate=0.05; days=365;
CRF=rate*(1+rate)^years/((1+rate)^years-1);
price=profiles.price_MWh(:); f=mpc.branch(:,1); to=mpc.branch(:,2);
r=mpc.branch(:,3); x=mpc.branch(:,4);
Pd=(alpha*mpc.bus(:,3)/Sbase)*profiles.load_curve_pu(:)';
Qd=(alpha*mpc.bus(:,4)/Sbase)*profiles.load_curve_pu(:)';
Afrom=sparse(f,1:Nb,1,N,Nb); Ato=sparse(to,1:Nb,1,N,Nb);
Acand=sparse(cand,1:Nc,1,N,Nc); Aslack=sparse(1,1,1,N,1);

% 规划变量跨24时段固定；运行变量逐时变化。
z=binvar(Nc,1,'full'); w=binvar(Nc,K,'full');
soc=sdpvar(Nc,T,'full'); delta=sdpvar(Nc,K,T,'full');
pch=sdpvar(Nc,T,'full'); pdis=sdpvar(Nc,T,'full'); u=binvar(Nc,T,'full');
U=sdpvar(N,T,'full'); P=sdpvar(Nb,T,'full'); Q=sdpvar(Nb,T,'full');
Pg=sdpvar(1,T,'full'); Qg=sdpvar(1,T,'full');
Pr=w*Popt'; Er=w*Eopt';
C=[];
for i=1:Nc
    % 每站最多选择一档；两组上界同时控制额定功率与充放电互斥。
    C=[C,sum(w(i,:))==z(i),socMin<=soc(i,:)<=socMax,soc(i,T)==soc0];
    C=[C,0<=pch(i,:)<=Pr(i),0<=pdis(i,:)<=Pr(i)];
    C=[C,pch(i,:)<=max(Popt)*u(i,:),pdis(i,:)<=max(Popt)*(1-u(i,:))];
    for k=1:K
        d=reshape(delta(i,k,:),1,T);
        % 四条紧致大M约束：delta=w*SoC，M取物理上下界0.20与0.80。
        C=[C,d>=socMin*w(i,k),d<=socMax*w(i,k)];
        C=[C,d>=soc(i,:)-socMax*(1-w(i,k)),d<=soc(i,:)-socMin*(1-w(i,k))];
    end
    for t=1:T
        if t==1, previous=Eopt*(soc0*w(i,:))';
        else, previous=Eopt*reshape(delta(i,:,t-1),K,1); end
        current=Eopt*reshape(delta(i,:,t),K,1);
        C=[C,current-previous==(etaCh*pch(i,t)-pdis(i,t)/etaDis)*dt];
    end
end
% LinDistFlow：省略损耗项，未将交流网损收益重复扣入目标函数。
C=[C,Ato*P-Afrom*P+Aslack*Pg+Acand*((pdis-pch)/Sbase)==Pd];
C=[C,Ato*Q-Afrom*Q+Aslack*Qg==Qd];
C=[C,U(1,:)==1,VminLin^2<=U(2:end,:)<=1.05^2];
for b=1:Nb
    C=[C,U(to(b),:)==U(f(b),:)-2*(r(b)*P(b,:)+x(b)*Q(b,:))];
end
investment=CRF*sum(cP*Pr+cE*Er); maintenance=cOM*sum(Pr);
grid=days*sum((Sbase*Pg').*price)*dt;
objective=investment+maintenance+grid;
ops=sdpsettings('solver','intlinprog','verbose',0,'savesolveroutput',1);
ops.intlinprog.RelativeGapTolerance=1e-8; ops.intlinprog.AbsoluteGapTolerance=1e-4;
ops.intlinprog.ConstraintTolerance=1e-9;
ops.intlinprog.MaxTime=180;
timer=tic; sol=optimize(C,objective,ops); seconds=toc(timer);
D=struct('StuID',Stu_ID,'Case',case_name,'Alpha',alpha,'CandidateBuses',cand,...
    'VminLin',VminLin,'EnergyCostMultiplier',energy_multiplier,'Solver','intlinprog',...
    'SolverFile',which('intlinprog'),'Problem',sol.problem,'Info',sol.info,'SolveSeconds',seconds);
if sol.problem~=0
    D.Feasible=false; return;
end
assert(sol.solveroutput.exitflag==1,'求解器未证明满足最优间隙要求。');
D.Feasible=true; D.SolverOutput=sol.solveroutput.output; D.Exitflag=sol.solveroutput.exitflag;
D.Z=round(value(z)); D.W=round(value(w)); D.RatedPowerMW=value(Pr); D.RatedEnergyMWh=value(Er);
D.SoC=value(soc); D.Delta=value(delta); D.ChargeMW=value(pch); D.DischargeMW=value(pdis);
D.ChargeState=value(u); D.U=value(U); D.P=value(P); D.Q=value(Q); D.PgridMW=Sbase*value(Pg);
D.QgridMvar=Sbase*value(Qg); D.Vlin=sqrt(D.U);
D.Cost=struct('InvestmentAnnual',value(investment),'MaintenanceAnnual',value(maintenance),...
    'GridAnnual',value(grid),'TotalAnnual',value(objective),'CRF',CRF,'cP',cP,'cE',cE,'cOM',cOM);
D.Parameters=struct('etaCh',etaCh,'etaDis',etaDis,'SoCmin',socMin,'SoCmax',socMax,'SoC0',soc0,...
    'Days',days,'dt',dt,'Sbase',Sbase,'PowerOptions',Popt,'EnergyOptions',Eopt,'LifeYears',years,'DiscountRate',rate);
D.PriceMWh=price; D.LoadMW=Pd*Sbase; D.QloadMvar=Qd*Sbase;

% 用保存的纯数值解独立检查约束，不将求解器返回成功视为全部校验通过。
balanceP=Ato*D.P-Afrom*D.P+Aslack*(D.PgridMW/Sbase)+Acand*((D.DischargeMW-D.ChargeMW)/Sbase)-Pd;
balanceQ=Ato*D.Q-Afrom*D.Q+Aslack*(D.QgridMvar/Sbase)-Qd;
energy=D.RatedEnergyMWh.*(D.SoC-[soc0*ones(Nc,1),D.SoC(:,1:end-1)])-...
    (etaCh*D.ChargeMW-D.DischargeMW/etaDis)*dt;
voltage=D.U(to,:)-D.U(f,:)+2*(r.*D.P+x.*D.Q);
product=D.Delta-reshape(D.SoC,Nc,1,T).*reshape(D.W,Nc,K,1);
check=struct('PowerBalanceMW',max(abs(balanceP),[],'all')*Sbase,...
    'ReactiveBalanceMvar',max(abs(balanceQ),[],'all')*Sbase,...
    'EnergyBalanceMWh',max(abs(energy),[],'all'),'VoltageEquation',max(abs(voltage),[],'all'),...
    'BigMProduct',max(abs(product),[],'all'),'MaxSimultaneousMW',max(min(D.ChargeMW,D.DischargeMW),[],'all'),...
    'EndSoCError',max(abs(D.SoC(:,T)-soc0)),...
    'BinaryError',max(abs(D.ChargeState-round(D.ChargeState)),[],'all'));
check.BoundsViolation=max([0;socMin-D.SoC(:);D.SoC(:)-socMax;-D.ChargeMW(:);-D.DischargeMW(:);...
    reshape(D.ChargeMW-D.RatedPowerMW,[],1);reshape(D.DischargeMW-D.RatedPowerMW,[],1);...
    reshape(VminLin^2-D.U(2:end,:),[],1);reshape(D.U(2:end,:)-1.05^2,[],1)]);
check.Passed=check.PowerBalanceMW<1e-5 && check.ReactiveBalanceMvar<1e-5 && ...
    check.EnergyBalanceMWh<1e-5 && check.VoltageEquation<1e-7 && check.BigMProduct<1e-6 && ...
    check.MaxSimultaneousMW<1e-6 && check.EndSoCError<1e-7 && check.BoundsViolation<1e-6 && check.BinaryError<1e-6;
assert(check.Passed,'规划解的独立约束校验失败。');

% 全24时段、全节点交流潮流校核；每小时都从同一原始算例重新构造负荷。
Vbase=zeros(N,T); Vess=Vbase; lossesBase=zeros(T,1); lossesESS=lossesBase;
gridBase=zeros(T,1); gridESS=gridBase; convergence=true(T,2);
pfopts=mpoption('verbose',0,'out.all',0,'pf.tol',1e-10);
for t=1:T
    base=mpc; base.bus(:,3)=Pd(:,t)*Sbase; base.bus(:,4)=Qd(:,t)*Sbase;
    ac0=runpf(base,pfopts); convergence(t,1)=ac0.success;
    withESS=base; withESS.bus(cand,3)=withESS.bus(cand,3)-D.DischargeMW(:,t)+D.ChargeMW(:,t);
    ac1=runpf(withESS,pfopts); convergence(t,2)=ac1.success;
    assert(all(convergence(t,:)),'第%d小时交流潮流不收敛。',t);
    Vbase(:,t)=ac0.bus(:,8); Vess(:,t)=ac1.bus(:,8);
    lossesBase(t)=sum(real(get_losses(ac0))); lossesESS(t)=sum(real(get_losses(ac1)));
    gridBase(t)=sum(ac0.gen(:,2)); gridESS(t)=sum(ac1.gen(:,2));
end
% 无储能线性基准用于相同模型口径的经济比较；交流基准用于工程复核。
Pbase=(Ato(2:end,:)-Afrom(2:end,:))\Pd(2:end,:);
Qbase=(Ato(2:end,:)-Afrom(2:end,:))\Qd(2:end,:);
B=Afrom'-Ato'; Ubase=[ones(1,T);B(:,2:end)\(2*(r.*Pbase+x.*Qbase)-B(:,1)*ones(1,T))];
D.VlinBase=sqrt(Ubase); D.VacBase=Vbase; D.Vac=Vess;
D.LossBaseMW=lossesBase; D.LossMW=lossesESS; D.ACGridBaseMW=gridBase; D.ACGridMW=gridESS;
[D.WorstBus,D.WorstHour]=ind2sub(size(Vbase),find(Vbase==min(Vbase,[],'all'),1));
D.MinACVoltage=min(Vess,[],'all'); D.MaxACVoltage=max(Vess,[],'all');
D.MinBaseVoltage=min(Vbase,[],'all'); D.MinLinearVoltage=min(D.Vlin,[],'all');
D.MaxVoltageError=max(abs(D.Vlin-Vess),[],'all');
D.LossBenefitAnnual=days*sum((lossesBase-lossesESS).*price)*dt;
D.Cost.BaseLinearGridAnnual=days*sum(sum(Pd,1)'.*price)*Sbase*dt;
D.Cost.BaseACGridAnnual=days*sum(gridBase.*price)*dt;
D.Cost.ACGridAnnual=days*sum(gridESS.*price)*dt;
D.Cost.ACTotalAnnual=D.Cost.InvestmentAnnual+D.Cost.MaintenanceAnnual+D.Cost.ACGridAnnual;
D.Cost.ModelNetSavingAnnual=D.Cost.BaseLinearGridAnnual-D.Cost.TotalAnnual;
D.Cost.ACNetSavingAnnual=D.Cost.BaseACGridAnnual-D.Cost.ACTotalAnnual;
D.Cost.ModelArbitrageAnnual=D.Cost.BaseLinearGridAnnual-D.Cost.GridAnnual;
check.ACConverged=all(convergence,'all');
check.ACVoltagePassed=D.MinACVoltage>=0.95-1e-7 && D.MaxACVoltage<=1.05+1e-7;
check.ACPowerBalanceMW=max(abs(gridESS-(sum(D.LoadMW,1)'-sum(D.DischargeMW-D.ChargeMW,1)'+lossesESS)));
assert(check.ACPowerBalanceMW<1e-5,'交流潮流有功平衡校验失败。');
D.Check=check;
D.Configuration=table(cand(:),D.Z,D.RatedPowerMW,D.RatedEnergyMWh,...
    'VariableNames',{'Node','Installed','RatedPower_MW','RatedEnergy_MWh'});
fprintf('VminLin=%.3f, cE倍率=%.2f：节点%s，P=%s MW，E=%s MWh，年费用=%.6f万元，AC最低=%.8f，耗时%.2fs\n',...
    VminLin,energy_multiplier,mat2str(cand(D.Z==1)),mat2str(D.RatedPowerMW',5),...
    mat2str(D.RatedEnergyMWh',5),D.Cost.TotalAnnual/1e4,D.MinACVoltage,seconds);
end
