#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import numpy as np

def plot_performance_metrics():
    """
    绘制性能指标图表：cycles、instructions、ipc
    横轴：不同的n值
    不同线条：workload和intrinsics的组合
    分两张图显示，每张图显示一半的workload
    """
    
    # 读取CSV文件
    csv_path = Path("build/test_results/results.csv")
    df = pd.read_csv(csv_path)
    
    # 创建workload和intrinsics的组合标签
    df['combination'] = df['workload'].astype(str) + '-' + df['intrinsics'].astype(str)
    
    # 只保留PASS状态的数据
    df_pass = df[df['status'] == 'PASS'].copy()
    
    # 设置图表样式
    try:
        plt.style.use('seaborn-v0_8')
    except:
        try:
            plt.style.use('seaborn')
        except:
            plt.style.use('default')
    
    # 获取所有组合
    combinations = sorted(df_pass['combination'].unique())
    
    # 按workload分组
    workload_groups = {}
    for combo in combinations:
        workload = combo.split('-')[0]
        if workload not in workload_groups:
            workload_groups[workload] = []
        workload_groups[workload].append(combo)
    
    # 分成两组workload
    workload_keys = sorted(workload_groups.keys(), key=int)
    mid_point = len(workload_keys) // 2
    group1_workloads = workload_keys[:mid_point]  # 前一半
    group2_workloads = workload_keys[mid_point:]  # 后一半
    
    group1_combinations = []
    group2_combinations = []
    
    for workload in group1_workloads:
        group1_combinations.extend(workload_groups[workload])
    
    for workload in group2_workloads:
        group2_combinations.extend(workload_groups[workload])
    
    # 绘制第一组
    plot_group(df_pass, group1_combinations, "Group 1", 
               f"Workloads: {', '.join(group1_workloads)}", "group1")
    
    # 绘制第二组
    plot_group(df_pass, group2_combinations, "Group 2", 
               f"Workloads: {', '.join(group2_workloads)}", "group2")
    
    # 打印数据统计信息
    print("数据统计信息:")
    print(f"总数据点数: {len(df)}")
    print(f"PASS状态数据点数: {len(df_pass)}")
    print(f"FAIL状态数据点数: {len(df[df['status'] == 'FAIL'])}")
    print(f"workload-intrinsics组合数: {len(combinations)}")
    print(f"组合列表: {combinations}")
    print(f"\n第一组 ({', '.join(group1_workloads)}): {group1_combinations}")
    print(f"第二组 ({', '.join(group2_workloads)}): {group2_combinations}")

def plot_group(df_pass, combinations, group_name, subtitle, file_prefix):
    """
    绘制单个组的图表
    """
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))
    
    # 定义颜色 - 使用tab10足够了
    colors = plt.cm.tab10(np.linspace(0, 1, len(combinations)))
    
    # 绘制cycles图表
    ax1 = axes[0]
    for i, combo in enumerate(combinations):
        combo_data = df_pass[df_pass['combination'] == combo].sort_values('n')
        ax1.plot(combo_data['n'], combo_data['cycles'], 
                marker='o', 
                label=f'{combo}', 
                color=colors[i], 
                linewidth=2.5, 
                markersize=6)
    
    ax1.set_xlabel('n', fontsize=11)
    ax1.set_ylabel('Cycles', fontsize=11)
    ax1.set_title(f'Cycles vs n - {group_name}', fontsize=12, fontweight='bold')
    ax1.set_xscale('log', basex=2)
    ax1.set_yscale('log')
    ax1.grid(True, alpha=0.3)
    ax1.legend(fontsize=9)
    
    # 绘制instructions图表
    ax2 = axes[1]
    for i, combo in enumerate(combinations):
        combo_data = df_pass[df_pass['combination'] == combo].sort_values('n')
        ax2.plot(combo_data['n'], combo_data['instructions'], 
                marker='s', 
                label=f'{combo}', 
                color=colors[i], 
                linewidth=2.5, 
                markersize=6)
    
    ax2.set_xlabel('n', fontsize=11)
    ax2.set_ylabel('Instructions', fontsize=11)
    ax2.set_title(f'Instructions vs n - {group_name}', fontsize=12, fontweight='bold')
    ax2.set_xscale('log', basex=2)
    ax2.set_yscale('log')
    ax2.grid(True, alpha=0.3)
    ax2.legend(fontsize=9)
    
    # 绘制IPC图表
    ax3 = axes[2]
    for i, combo in enumerate(combinations):
        combo_data = df_pass[df_pass['combination'] == combo].sort_values('n')
        ax3.plot(combo_data['n'], combo_data['ipc'], 
                marker='^', 
                label=f'{combo}', 
                color=colors[i], 
                linewidth=2.5, 
                markersize=6)
    
    ax3.set_xlabel('n', fontsize=11)
    ax3.set_ylabel('IPC (Instructions Per Cycle)', fontsize=11)
    ax3.set_title(f'IPC vs n - {group_name}', fontsize=12, fontweight='bold')
    ax3.set_xscale('log', basex=2)
    ax3.grid(True, alpha=0.3)
    ax3.legend(fontsize=9)
    
    # 添加副标题
    fig.suptitle(subtitle, fontsize=10, y=0.02)
    
    # 调整布局
    plt.tight_layout()
    plt.subplots_adjust(bottom=0.1)
    
    # 保存图表
    plt.savefig(f'performance_metrics_{file_prefix}.png', dpi=300, bbox_inches='tight')
    plt.show()

def plot_individual_charts():
    """
    分别绘制独立的图表，也分成两组
    """
    # 读取CSV文件
    csv_path = Path("build/test_results/results.csv")
    df = pd.read_csv(csv_path)
    
    # 创建workload和intrinsics的组合标签
    df['combination'] = df['workload'].astype(str) + '-' + df['intrinsics'].astype(str)
    
    # 只保留PASS状态的数据
    df_pass = df[df['status'] == 'PASS'].copy()
    
    # 获取所有组合
    combinations = sorted(df_pass['combination'].unique())
    
    # 按workload分组
    workload_groups = {}
    for combo in combinations:
        workload = combo.split('-')[0]
        if workload not in workload_groups:
            workload_groups[workload] = []
        workload_groups[workload].append(combo)
    
    # 分成两组workload
    workload_keys = sorted(workload_groups.keys(), key=int)
    mid_point = len(workload_keys) // 2
    group1_workloads = workload_keys[:mid_point]
    group2_workloads = workload_keys[mid_point:]
    
    group1_combinations = []
    group2_combinations = []
    
    for workload in group1_workloads:
        group1_combinations.extend(workload_groups[workload])
    
    for workload in group2_workloads:
        group2_combinations.extend(workload_groups[workload])
    
    # 为每个指标绘制两组图表
    metrics = ['cycles', 'instructions', 'ipc']
    metric_labels = ['Cycles', 'Instructions', 'IPC (Instructions Per Cycle)']
    
    for metric, label in zip(metrics, metric_labels):
        plot_individual_metric(df_pass, group1_combinations, group2_combinations, 
                             metric, label, group1_workloads, group2_workloads)

def plot_individual_metric(df_pass, group1_combinations, group2_combinations, 
                          metric, label, group1_workloads, group2_workloads):
    """
    绘制单个指标的两组图表
    """
    # 第一组
    plt.figure(figsize=(14, 8))
    colors = plt.cm.tab10(np.linspace(0, 1, len(group1_combinations)))
    
    for i, combo in enumerate(group1_combinations):
        combo_data = df_pass[df_pass['combination'] == combo].sort_values('n')
        plt.plot(combo_data['n'], combo_data[metric], 
                marker='o', 
                label=f'{combo}', 
                color=colors[i], 
                linewidth=3, 
                markersize=8)
    
    plt.xlabel('n', fontsize=14)
    plt.ylabel(label, fontsize=14)
    plt.title(f'{label} vs n - Group 1 (Workloads: {", ".join(group1_workloads)})', 
              fontsize=16, fontweight='bold')
    plt.xscale('log', basex=2)
    if metric in ['cycles', 'instructions']:
        plt.yscale('log')
    plt.grid(True, alpha=0.3)
    plt.legend(fontsize=12)
    plt.tight_layout()
    plt.savefig(f'{metric}_chart_group1.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    # 第二组
    plt.figure(figsize=(14, 8))
    colors = plt.cm.tab10(np.linspace(0, 1, len(group2_combinations)))
    
    for i, combo in enumerate(group2_combinations):
        combo_data = df_pass[df_pass['combination'] == combo].sort_values('n')
        plt.plot(combo_data['n'], combo_data[metric], 
                marker='o', 
                label=f'{combo}', 
                color=colors[i], 
                linewidth=3, 
                markersize=8)
    
    plt.xlabel('n', fontsize=14)
    plt.ylabel(label, fontsize=14)
    plt.title(f'{label} vs n - Group 2 (Workloads: {", ".join(group2_workloads)})', 
              fontsize=16, fontweight='bold')
    plt.xscale('log', basex=2)
    if metric in ['cycles', 'instructions']:
        plt.yscale('log')
    plt.grid(True, alpha=0.3)
    plt.legend(fontsize=12)
    plt.tight_layout()
    plt.savefig(f'{metric}_chart_group2.png', dpi=300, bbox_inches='tight')
    plt.show()

if __name__ == "__main__":
    print("绘制性能指标图表...")
    
    # 绘制组合图表
    print("1. 绘制分组组合图表")
    plot_performance_metrics()
    
    print("\n" + "="*50)
    
    # 绘制独立图表
    print("2. 绘制分组独立图表")
    plot_individual_charts()
    
    print("\n绘制完成！")
    print("生成的文件:")
    print("- performance_metrics_group1.png (第一组组合图表)")
    print("- performance_metrics_group2.png (第二组组合图表)")
    print("- cycles_chart_group1.png, cycles_chart_group2.png (cycles分组图表)")
    print("- instructions_chart_group1.png, instructions_chart_group2.png (instructions分组图表)")
    print("- ipc_chart_group1.png, ipc_chart_group2.png (ipc分组图表)") 