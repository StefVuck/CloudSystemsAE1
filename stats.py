import json
import requests
import numpy as np
import pandas as pd
from scipy.stats import f_oneway
from statsmodels.stats.multicomp import pairwise_tukeyhsd
import statsmodels.api as sm
from statsmodels.formula.api import ols

def decode_json(file_path: str) -> dict:
    file_string = ""
    with open(file_path) as f:
        file_string = f.read()
    return json.loads(file_string)

def query_prometheus(metric:str, timeframe:str, prometheus_url:str="localhost:9090") -> dict:
    request_str = f"http://{prometheus_url}/api/v1/query?query={metric}[{timeframe}]"
    return json.loads(requests.get(request_str).text)

def add_metric_to_df(metric:str, duration:str, platforms:list[tuple]=[("none", "localhost")]) -> pd.DataFrame:
    def getSecondValue(val) -> int:
        return int(val[1])

    # df = pd.DataFrame(columns = ["value", "platform", "metric"])
    dfs = []

    for platform, cluster_ip in platforms:
        dictionary = query_prometheus(metric, duration, f"{cluster_ip}:9090")
        values = list(map(getSecondValue, dictionary['data']['result'][0]['values'])) # I *Think* each list is [Epoch, value(str)]
        dfs.append(pd.DataFrame({
            'value': values,
            'platform': len(values) * [platform],
            'metric': len(values) * [metric]
            }))

    return(pd.concat(dfs))


if __name__ == '__main__':
    alpha=0.05
    timeframe = "5m"
    # Eventually going to have something like:
    # requests = [("AWS", "$AWS_ENDPOINT"), ("GCP", "$GCP_ENDPOINT"), ("AZURE", "$AZURE_ENDPOINT")]
    requests = [("none", "localhost"), ("yone", "localhost")]

    metrics_dfs = []
    metrics = ["network_connection_errors_total", 'network_throughput_bytes_total{direction="upload"}', 'network_throughput_bytes_total{direction="download"}'] # Add latency
    for metric in metrics:
        metrics_dfs.append(add_metric_to_df(metric, timeframe, requests))

    df = pd.concat(metrics_dfs)

    for metric in metrics:
        print(f"----Testing {metric}----")

        sub_df = df[(df["metric"] == metric)]

        model = ols('value ~ platform', data=sub_df).fit()

        anova_table = sm.stats.anova_lm(model, typ=1)

        p_value = anova_table.loc['platform', 'PR(>F)']

        if p_value < alpha:
            print("Performing Tukey Test")
            tukey_result = pairwise_tukeyhsd(endog=sub_df['value'], groups=df['platform'], alpha=alpha)
            print(tukey_result.summary())
            if (any(tukey_result.reject)):
                print("Statistically significant difference (Tukey)")
            else:
                print("No Statistically significant difference (Tukey)")

        else:
            print("No statistically significant difference (Anova)")
        print(f"----Finish {metric}----")
