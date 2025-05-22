# Azure Cost Estimation for IPFS Nodes

This document provides guidance on estimating and optimizing costs for running IPFS nodes on Azure.

## Cost Components

Running an IPFS node on Azure involves several cost components:

1. **Virtual Machine (Compute)**
2. **Storage (Azure Files)**
3. **Bandwidth (Network Egress)**
4. **Backup (Optional)**

## Virtual Machine Recommendations

| Workload Type | Recommended VM Size | Estimated Cost (USD/month)* |
|---------------|---------------------|----------------------------|
| Light         | B2s (2 vCPU, 4 GB)  | $30-40                     |
| Medium        | D2s_v3 (2 vCPU, 8 GB)| $70-90                    |
| Heavy         | D4s_v3 (4 vCPU, 16 GB)| $140-180                 |

*Prices are approximate and may vary by region and with Azure pricing changes.

### Considerations:
- CPU: IPFS is moderately CPU-intensive, especially when processing many requests
- Memory: More memory allows for larger routing tables and better caching
- Disk I/O: SSD-backed instances are strongly recommended

## Storage Costs

| Storage Type | Use Case | Estimated Cost (USD/month) |
|--------------|----------|----------------------------|
| Azure Files Standard (1TB) | General purpose | $80-100 |
| Azure Files Premium (1TB) | High performance | $150-200 |

### Considerations:
- IPFS data grows over time as you pin more content
- Start with a smaller allocation and increase as needed
- Consider lifecycle management for older, less accessed content

## Bandwidth Costs

Azure charges for outbound data transfer (egress) but not for inbound (ingress).

| Monthly Egress | Estimated Cost (USD) |
|----------------|----------------------|
| 100 GB         | $8-12                |
| 500 GB         | $40-60               |
| 1 TB           | $80-120              |
| 5 TB           | $400-600             |

### Considerations:
- This is where the bandwidth manager becomes crucial
- Set appropriate daily/monthly limits based on your budget
- Consider using Azure CDN for frequently accessed public content

## Cost Optimization Strategies

1. **Right-size VM**
   - Start with a smaller VM and scale up if needed
   - Monitor CPU, memory, and disk usage to determine optimal size

2. **Use Reserved Instances**
   - Save 20-40% with 1-year or 3-year reservations
   - Ideal for long-running IPFS nodes

3. **Optimize Storage**
   - Use the bandwidth manager to limit unnecessary content storage
   - Implement garbage collection (`ipfs repo gc`) regularly
   - Consider tiered storage for less frequently accessed content

4. **Control Bandwidth**
   - Use the bandwidth manager's daily and monthly limits
   - Set `DAILY_LIMIT_GB` and `MONTHLY_LIMIT_GB` based on your budget
   - Consider time-based throttling during peak hours

5. **Monitor and Alert**
   - Set up Azure Cost Management alerts
   - Monitor bandwidth usage with the bandwidth manager
   - Adjust limits proactively before exceeding budget

## Sample Monthly Cost Scenarios

### Minimal Node
- B2s VM: $30
- 100GB Azure Files Standard: $8
- 200GB Bandwidth: $16
- **Total: ~$54/month**

### Standard Node
- D2s_v3 VM: $80
- 500GB Azure Files Standard: $40
- 1TB Bandwidth: $90
- **Total: ~$210/month**

### Enterprise Node
- D4s_v3 VM: $160
- 2TB Azure Files Premium: $300
- 5TB Bandwidth: $450
- **Total: ~$910/month**

## Conclusion

The bandwidth manager in this repository is designed to help you control the most variable cost component: network egress. By setting appropriate limits, you can ensure your IPFS node operates within your budget while still providing the services you need.

For the most accurate and up-to-date pricing, always refer to the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/).

<!-- FLAG: Created 2025-05-22T10:54:11-04:00 -->
