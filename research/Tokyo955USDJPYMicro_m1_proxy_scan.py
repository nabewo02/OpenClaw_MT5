import pandas as pd
from pathlib import Path
from datetime import date, timedelta

BASE_DIR = Path(__file__).resolve().parents[2]
PATH = BASE_DIR / 'historical_data/USDJPY(TDS)_M1_201501010000_202412310000.csv'
POINT = 0.001
SPREAD_POINTS = 10.0


def nth_weekday(year, month, weekday, n):
    d = date(year, month, 1)
    while d.weekday() != weekday:
        d += timedelta(days=1)
    return d + timedelta(days=7 * (n - 1))


def is_us_dst(d):
    start = nth_weekday(d.year, 3, 6, 2)
    end = nth_weekday(d.year, 11, 6, 1)
    return start <= d < end


def load_df():
    df = pd.read_csv(
        PATH,
        sep='\t',
        usecols=['<DATE>', '<TIME>', '<OPEN>', '<HIGH>', '<LOW>', '<CLOSE>', '<TICKVOL>'],
        dtype={'<OPEN>': 'float32', '<HIGH>': 'float32', '<LOW>': 'float32', '<CLOSE>': 'float32', '<TICKVOL>': 'int32'},
    )
    df['dt'] = pd.to_datetime(df['<DATE>'] + ' ' + df['<TIME>'])
    df = df.rename(columns={'<OPEN>': 'open', '<HIGH>': 'high', '<LOW>': 'low', '<CLOSE>': 'close', '<TICKVOL>': 'tickvol'})
    df = df[['dt', 'open', 'high', 'low', 'close', 'tickvol']]
    df['date'] = df['dt'].dt.date
    df['hour'] = df['dt'].dt.hour
    df['minute'] = df['dt'].dt.minute
    return df


def simulate(df, mode='auto', drift_atr_th=0.4, vol_z_th=2.0, tp_mult=0.6, sl_mult=0.35):
    trades = []
    yearly = {}
    for day_date, day in df.groupby('date', sort=True):
        fix_hour = 3 if is_us_dst(day_date) else 2
        day = day.set_index(['hour', 'minute'])
        pre_times = [(fix_hour, m) for m in range(45, 55)]
        fix_time = (fix_hour, 55)
        entry_time = (fix_hour, 56)
        post_times = [(fix_hour, 56), (fix_hour, 57), (fix_hour, 58), (fix_hour, 59), ((fix_hour + 1) % 24, 0), ((fix_hour + 1) % 24, 1), ((fix_hour + 1) % 24, 2), ((fix_hour + 1) % 24, 3)]
        timeout_time = ((fix_hour + 1) % 24, 4)
        prev_hour = (fix_hour - 1) % 24
        prev60 = [(prev_hour, m) for m in range(45, 60)] + [(fix_hour, m) for m in range(0, 45)]
        needed = pre_times + [fix_time, entry_time, timeout_time] + post_times + prev60
        if not all(t in day.index for t in needed):
            continue

        pre = day.loc[pre_times]
        fix = day.loc[fix_time]
        entry = day.loc[entry_time]
        post = day.loc[post_times]
        prev = day.loc[prev60]

        prev_close = pre['close'].shift(1)
        tr = pd.concat([(pre['high'] - pre['low']), (pre['high'] - prev_close).abs(), (pre['low'] - prev_close).abs()], axis=1).max(axis=1)
        atr = float(tr.mean())
        if atr <= 0:
            continue

        drift = float(pre.iloc[-1]['close'] - pre.iloc[0]['open'])
        sign = 1 if drift > 0 else -1 if drift < 0 else 0
        if sign == 0:
            continue

        drift_atr = abs(drift) / atr
        vol_mean = float(prev['tickvol'].mean())
        vol_std = float(prev['tickvol'].std(ddof=0))
        pre_vol = float(pre['tickvol'].mean())
        vol_z = (pre_vol - vol_mean) / vol_std if vol_std > 0 else 0.0
        if drift_atr < drift_atr_th or vol_z < vol_z_th:
            continue

        pre_high = float(pre['high'].max())
        pre_low = float(pre['low'].min())
        cont = 0
        rev = 0
        if sign > 0:
            if float(fix['close']) > pre_high and float(fix['close']) > float(fix['open']):
                cont = 1
            if float(fix['high']) > pre_high and float(fix['close']) < pre_high and float(fix['close']) < float(fix['open']):
                rev = -1
        else:
            if float(fix['close']) < pre_low and float(fix['close']) < float(fix['open']):
                cont = -1
            if float(fix['low']) < pre_low and float(fix['close']) > pre_low and float(fix['close']) > float(fix['open']):
                rev = 1

        signal = cont if mode == 'continuation' else rev if mode == 'reversal' else (cont if cont != 0 else rev)
        if signal == 0:
            continue

        entry_price = float(entry['open']) + (SPREAD_POINTS * POINT / 2 if signal > 0 else -SPREAD_POINTS * POINT / 2)
        tp_dist = atr * tp_mult
        sl_dist = min(atr * sl_mult, entry_price * 0.0025)
        tp = entry_price + tp_dist if signal > 0 else entry_price - tp_dist
        sl = entry_price - sl_dist if signal > 0 else entry_price + sl_dist

        exit_price = None
        for _, bar in post.iterrows():
            high = float(bar['high'])
            low = float(bar['low'])
            if signal > 0:
                if low <= sl:
                    exit_price = sl
                    break
                if high >= tp:
                    exit_price = tp
                    break
            else:
                if high >= sl:
                    exit_price = sl
                    break
                if low <= tp:
                    exit_price = tp
                    break

        if exit_price is None:
            exit_price = float(day.loc[timeout_time]['open'])

        pnl_points = ((exit_price - entry_price) / POINT if signal > 0 else (entry_price - exit_price) / POINT) - SPREAD_POINTS
        r = pnl_points / (sl_dist / POINT)
        trades.append(r)
        yearly[day_date.year] = yearly.get(day_date.year, 0.0) + r

    n = len(trades)
    wins = sum(1 for x in trades if x > 0)
    gp = sum(x for x in trades if x > 0)
    gl = -sum(x for x in trades if x < 0)
    pf = gp / gl if gl > 0 else 0.0
    return {
        'mode': mode,
        'drift_atr_th': drift_atr_th,
        'vol_z_th': vol_z_th,
        'tp_mult': tp_mult,
        'sl_mult': sl_mult,
        'trades': n,
        'win_rate': round(wins / n * 100, 2) if n else 0.0,
        'pf': round(pf, 4),
        'net_r': round(sum(trades), 2),
        'avg_r': round(sum(trades) / n, 3) if n else 0.0,
        'positive_years': sum(1 for v in yearly.values() if v > 0),
        'active_years': len(yearly),
    }


if __name__ == '__main__':
    df = load_df()
    tests = [
        ('continuation', 0.4, 2.0, 0.6, 0.35),
        ('reversal', 0.4, 2.0, 0.6, 0.35),
        ('auto', 0.4, 2.0, 0.6, 0.35),
        ('continuation', 0.0, 0.0, 1.2, 0.45),
        ('reversal', 0.0, 0.0, 1.2, 0.45),
        ('auto', 0.0, 0.0, 1.2, 0.45),
    ]
    for args in tests:
        print(simulate(df, *args))
