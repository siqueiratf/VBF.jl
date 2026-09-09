using CSV
using DataFrames
using Plots

# 1. Read the CSV file into a DataFrame
# Replace "data.csv" with the path to your file
df = CSV.read("/home/ts/VBF.jl/analysis/generated/papers.csv", DataFrame)

# Quick look at the data structure (optional)
# println(first(df, 5)) 

# 2. Generate a basic plot
# Assuming your CSV has columns named 'x_column' and 'y_column'
plot(df.paper_id, df.corpus_members, 
     title = "Teste de gráfico",
     xlabel = "paper_id",
     ylabel = "corpus_members",
     label = "Data Series 1",
     linewidth = 2,
     color = :blue)

# 3. Save the plot to your computer
savefig("teste.png")


