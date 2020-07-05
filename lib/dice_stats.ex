defmodule DiceStats do
  @moduledoc """
  This module empirically calculates the odds of rolling a result for exploding dice sets
  in the game deadlands.

  There are two main rolls: 
  - Skill/Aptitude Rolls, where you roll something like 5d12 against a target number. In this roll
    only the highest roll is counted, and if the majority of the dice come up 1s then the roll
    fails no matter what the other dice are. It's the critical fail mechanic.
  - Damage rolls, where the dice get added up and there is no failure
  """

  alias Elixlsx.Workbook
  alias Elixlsx.Sheet

  # Because we are calculating things empirically, we need to set our sample size for each thing
  # we are calculating stats for. There are 110 experiments in this script and they each get rolled
  # this number of times.
  @iterations 1000000
  @timeout 10*60*1000

  @doc """
  Calculates the results from a set of aptitude roll results (bust/0 or pick the highest)
 
  ## Examples:
      iex> DiceStats.roll_res_or_bust(1, [1])
      0
      iex> DiceStats.roll_res_or_bust(2, [1,2])
      2
      iex> DiceStats.roll_res_or_bust(2, [1,1])
      0
  """
  def roll_res_or_bust(num, res) do
    fails = res
      |> Enum.filter( &(&1 == 1) )
      |> Enum.count()

    # We have to get a majority of 1s for a bust
    # i.e if you have 2 dice, we need 2 fails because 1 fail isn't a majority
    if fails > (num-fails) do
      0
    else 
      Enum.max(res)
    end
  end

  @doc """
  Rolls the dice for a single aptitude check. 0 if a bust, otherwise a single value
  """
  def single_aptitude_roll(num, sides) do
    roll_res_or_bust(num, ExDiceRoller.roll( "#{num}d#{sides}" , cache: true, opts: [:keep, :explode]))
  end 

  @doc """
  Calculates the percentage frequencies of a set of results
  
  ## Examples:
      iex> DiceStats.calculate_frequencies([1,2,2,2,2])
      [{1, 20.0}, {2, 80.0}]
  """
  def calculate_frequencies(res) do
    len = length(res)
    res
      |> Enum.frequencies()
      |> Enum.map( fn {k,v} -> {k, Float.round( (v / len) * 100 , 6 )} end )
  end

  @doc """
  Calculates the subtractive frequencies from 100% for a set of frequencies.
  You can view the result as a you have X% to get at least Y.
  
  ## Examples:
      iex> DiceStats.cumulative_frequencies([{0,2.5}, {2,25.0}, {3,50.0}, {5,20}, {6,2.5}])
      %{0 => 2.5, 2 => 97.5, 3 => 72.5, 5 => 22.5, 6 => 2.5}
  """
  def cumulative_frequencies(frequencies) do
    frequencies
      |> Enum.sort_by( fn {k,_} -> k end )
      |> Enum.map_reduce(
        100.0,
        fn {k,v}, acc ->
          {
            # We cheat a little an print the raw chance of a bust rather than the
            # decreasing cumulative total
            { k, if k == 0 do v else Float.round( acc, 2) end },
            acc - v
          }
        end
      )
      |> (fn {res, _} -> Map.new(res) end).()
  end  

  @doc """
  Repeatedly rolls an aptitude to estimate the cumulative frequencies of the roll
  """
  def aptitude_rolls(num, sides, iterations \\ @iterations) do
    (1..iterations)
      |> Task.async_stream( fn _ -> single_aptitude_roll(num,sides) end )
      |> Enum.map( fn {:ok, x} -> x end )
      |> calculate_frequencies()
      |> cumulative_frequencies()
  end

  @doc """
  Repeatedly rolls a damage roll to estimate the cumulative frequencies of the roll
  """
  def damage_rolls(num, sides, iterations \\ @iterations) do
    (1..iterations)
      |> Task.async_stream( fn _ -> ExDiceRoller.roll( "#{num}d#{sides}" , cache: true, opts: [:explode]) end )
      |> Enum.map( fn {:ok, x} -> x end )
      |> calculate_frequencies()
      |> cumulative_frequencies()
  end

  def cell( val, styles \\ [] ) do
    Enum.concat( [ val, font: "Arial", align_horizontal: :center ], styles )
  end

  def header( val ) do
    cell(val, [bold: true, color: "#FFFFFF", bg_color: "#4B86B4", border: [bottom: [style: :thin]]] )
  end

  def percentile_val_cell( val ) when is_float(val) do
    color = case Integer.floor_div( ceil(val), 25 ) do
      0 -> "#FA897B"
      1 -> "#FFDD94"
      2 -> "#D0E6A5"
      _ -> "#86E3CE"
    end
    cell(val, [color: "#000000", bg_color: color] )
  end
  def percentile_val_cell( val ) do
    cell(val, [color: "#000000", bg_color: "#FFFFFF"] )
  end

  def res_to_cols(res_map, first_col, max_cols) do
    Enum.concat( [first_col], (2..max_cols) )
      |> Enum.map( fn i -> percentile_val_cell( Map.get(res_map, i, "-") ) end )
  end

  def res_to_rows(num_res, first_col, max_cols, header_row) do
    Enum.concat(
      header_row,
      Enum.map( num_res,
        fn {num,res} -> Enum.concat(
          [ cell(num, [bold: true]) ],
          res_to_cols(res, first_col, max_cols)
        ) end
      ) 
    )
  end

  def sides_res_to_sheet( {sides,num_res}) do
    max_cols = 30
    %Sheet{
      name: "Aptitude d#{sides}",
      rows: res_to_rows(num_res, 0, max_cols, [ Enum.map( Enum.concat( ["", "Bust %"], (2..max_cols) ) , &header/1 ) ] ),
      col_widths: Map.new( 3..(max_cols+1), fn x -> {x, 5} end ) |> Map.put( 1, 3 ) |> Map.put( 2, 7 )
    }
  end

  def pivot_sides(res) do
    res
      |> Enum.map( fn {:ok, x} -> x end )
      |> Enum.group_by( fn {_,sides,_} -> sides end, fn {num,_,res} -> {num, res} end )
  end

  def aptitude_sheets() do
    (for n <- (1..10), s <- [4,6,8,10,12], do: {n,s} )
      |> Task.async_stream( fn {num,sides} -> {num, sides, aptitude_rolls(num,sides)} end, [timeout: @timeout] )
      |> pivot_sides()
      |> Enum.map( &sides_res_to_sheet/1 )
      |> Enum.to_list()
  end

  def damage_res_to_sheet( {sides,num_res} ) do
    max_cols = 50
    %Sheet{
      name: "Damage d#{sides}",
      rows: res_to_rows(num_res, 1, max_cols, [ Enum.map( Enum.concat( [""], (1..max_cols) ) , &header/1 ) ] ),
      col_widths: Map.new( 2..(max_cols+1), fn x -> {x, 5} end ) |> Map.put( 1, 3 ) 
    }
  end

  def damage_sheets() do
    (for n <- (1..10), s <- [4,6,8,10,12,20], do: {n,s} )
      |> Task.async_stream( fn {num,sides} -> {num, sides, damage_rolls(num,sides)} end, [timeout: @timeout] )
      |> pivot_sides()
      |> Enum.map( &damage_res_to_sheet/1 )
      |> Enum.to_list()
  end

  def run() do
    ExDiceRoller.start_cache()
    apts_sheets_task = Task.async( &aptitude_sheets/0 ) 
    damage_sheets_task = Task.async( &damage_sheets/0 ) 

    Elixlsx.write_to(
      %Workbook{
        sheets: Task.await(apts_sheets_task, @timeout) ++ Task.await(damage_sheets_task, @timeout)
      },
      "results.xlsx"
    )
  end
end
