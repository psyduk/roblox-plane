"""How a round feels to watch: attacks, hit rate, shot travel, cancelled charges, first-hit advantage and field scores.

Run from the repository root: build/testenv/bin/python scripts/qa/combat_feel.py 24 --pairs
The first argument is the number of seeds per ordered pairing. NAME=value or Skill.field=value overrides a constant for one run.
"""
import sys, statistics as st
sys.path.insert(0,'scripts')
from lupa import LuaRuntime
from lua_modules import load_battle
rt=LuaRuntime(unpack_returned_tuples=True)
sim,skills,cat=load_battle(rt)
OFF=['Meteor','Firework','MachineGun','Pinball','Sniper','Boomerang','BlackHole','UFOBeam']
FIRE=('rocket','burst','ricochet','dive','hole','beam','beam_miss')
def play(a,b,seed,wa=(),wb=()):
    s=sim.newRound(seed,rt.table_from({'offenceId':a,'wildIds':rt.table_from(list(wa))}),rt.table_from({'offenceId':b,'wildIds':rt.table_from(list(wb))}))
    seen=0; r=dict(wind=0,fire=[0],hits=[],first=None,flight=[],dodge=0,hitby={1:0,2:0},atkby={1:0,2:0}); last={}
    while not s.finished:
        sim.step(s,1/60)
        for e in s.events.values():
            if e.serial<=seen: continue
            seen=e.serial
            if e.kind=='windup': r['wind']+=1
            elif e.kind in FIRE: last[e.actor]=e.at; r['fire'].append(e.at)
            elif e.kind=='dodge': r['dodge']+=1
            elif e.kind in('hit','wake_hit'):
                r['hits'].append((e.at,e.actor)); r['hitby'][e.actor]+=1
                if r['first'] is None: r['first']=e.actor
                if e.kind=='hit' and e.actor in last: r['flight'].append(e.at-last[e.actor])
    r.update(dur=s.elapsed,reason=s.reason,winner=s.winner,atk=s.fighters[1].attacks+s.fighters[2].attacks)
    r['atkby']={1:s.fighters[1].attacks,2:s.fighters[2].attacks}
    return r
def report(seeds=range(1,13),offs=OFF,wa=(),wb=(),quiet=False):
    score={a:[0,0] for a in offs}; per={a:dict(atk=0,hit=0) for a in offs}; rows=[]; pair={}
    for a in offs:
        for b in offs:
            for seed in seeds:
                r=play(a,b,seed,wa,wb); rows.append(r)
                pa=1 if r['winner']==1 else .5 if r['winner']==0 else 0
                score[a][0]+=pa; score[a][1]+=1; score[b][0]+=1-pa; score[b][1]+=1
                pair[(a,b)]=pair.get((a,b),0)+pa/len(list(seeds))
                per[a]['atk']+=r['atkby'][1]; per[a]['hit']+=r['hitby'][1]; per[b]['atk']+=r['atkby'][2]; per[b]['hit']+=r['hitby'][2]
    n=len(rows); g=lambda k:[x[k] for x in rows]
    dec=[x for x in rows if x['winner'] in(1,2)]
    flight=sorted(f for x in rows for f in x['flight'])
    gaps=[]
    for x in rows:
        t=x['fire']+[x['dur']]; gaps.append(max(b-a for a,b in zip(t,t[1:])))
    cb=0
    for x in dec:
        sc={1:0,2:0}
        for _,h in x['hits']:
            sc[h]+=1
            if sc[3-x['winner']]>sc[x['winner']]: cb+=1; break
    out=dict(atk=st.mean(g('atk')),hit=100*sum(len(x['hits']) for x in rows)/sum(g('atk')),flight=st.median(flight) if flight else 0,
        fizz=100*(1-sum(g('atk'))/max(1,sum(g('wind')))),first=100*sum(1 for x in dec if x['first']==x['winner'])/max(1,len(dec)),comeback=100*cb/max(1,len(dec)),
        gap=st.median(gaps),dur=st.median(g('dur')),p90=sorted(g('dur'))[int(n*.9)],ko=100*sum(1 for x in rows if x['reason']=='knockout')/n,draw=100*sum(1 for x in rows if x['winner']==0)/n,dodge=st.mean(g('dodge')))
    if not quiet:
        print(' '.join(f"{k} {v:.1f}" if k!='flight' else f"{k} {v:.2f}" for k,v in out.items()))
        print('field  '+'  '.join(f"{a[:5]} {100*score[a][0]/score[a][1]:.0f}" for a in offs))
        print('hit%   '+'  '.join(f"{a[:5]} {100*per[a]['hit']/max(1,per[a]['atk']):.0f}" for a in offs))
        print('atk/rd '+'  '.join(f"{a[:5]} {per[a]['atk']/(2*len(offs)*len(list(seeds))):.1f}" for a in offs))
    return out,score,pair
def override(args):
    for a in args:
        if '=' not in a: continue
        k,v=a.split('=',1); v=float(v)
        if '.' in k:
            o,f=k.split('.'); (skills.offence[o] or skills.wild[o] or skills.form[o])[f]=v
        else: sim[k]=v
if __name__=='__main__':
    override(sys.argv[2:])
    n=int(sys.argv[1]) if len(sys.argv)>1 else 12
    out,score,pair=report(range(1,n+1))
    if '--pairs' in sys.argv:
        for a in OFF: print(f"{a[:6]:7s}"+' '.join(f"{100*pair[(a,b)]:3.0f}" for b in OFF))
