import matplotlib.pyplot as plt
import re

def readfile(path):
    times = []
    with open(path) as f:
        for line in f:
            m = re.match(r".*time=(?P<time>[0-9]*.[0-9]*)", line)
            if m:
                times.append(float(m.group("time")))

    return times

def plot_boxplot(results, path):
    fig = plt.figure()
    plt.boxplot(results, labels = ['AWS', 'Azure', 'GCP'])
    plt.title('Round trip time on various cloud providers')
    plt.ylabel('RTT (ms)')
    plt.xlabel('Cloud provider')
    plt.grid(True)
    plt.savefig(path)
    plt.clf()

if __name__ == "__main__":
    results = [
        readfile("aws_log.txt"),
        readfile("azure_log.txt"),
        readfile("gcp_log.txt")
    ]

    plot_boxplot(results, "boxplot.png")
