defmodule DiceStatsTest do
  use ExUnit.Case
  doctest DiceStats

  test "busts when majority are 1s" do
    assert DiceStats.roll_res_or_bust(1, [1]) == 0
    assert DiceStats.roll_res_or_bust(2, [1,1]) == 0
    assert DiceStats.roll_res_or_bust(2, [1,2]) == 2
    assert DiceStats.roll_res_or_bust(3, [1,1,1]) == 0
    assert DiceStats.roll_res_or_bust(3, [1,1,2]) == 0
    assert DiceStats.roll_res_or_bust(3, [1,3,2]) == 3
    assert DiceStats.roll_res_or_bust(4, [1,1,1,1]) == 0
    assert DiceStats.roll_res_or_bust(4, [1,1,1,4]) == 0
    assert DiceStats.roll_res_or_bust(4, [1,1,4,3]) == 4
  end

  test "calculate_frequencies" do
    assert DiceStats.calculate_frequencies([0,0,1,1,1,2,2,2,3,3,3,4]) ==
      [{0, 16.666667}, {1, 25.0}, {2, 25.0}, {3, 25}, {4, 8.333333}]
  end

  test "cumulative_frequencies" do
    test_freq=[
      {0,2.5},
      {2,25.0},
      {3,50.0},
      {5,20.0},
      {6,2.5},
    ]
    expected_out = %{
      0 => 2.5,
      2 => 97.5,
      3 => 72.5,
      5 => 22.5,
      6 => 2.5,
    }
    assert DiceStats.cumulative_frequencies(test_freq) == expected_out
  end

  def expected_styles(val, extra) do
    Enum.concat( [val], Enum.concat( [{:font, "Arial"}, {:align_horizontal, :center}], extra ) )
  end

  def expected_coloured_cell(val, fg, bg) do
    expected_styles( val, [{:color, fg}, {:bg_color, bg}] )
  end

  test "percentile_val handles - fine" do
    assert DiceStats.percentile_val_cell("-") == expected_coloured_cell( "-", "#000000", "#FFFFFF" )
  end

  test "percentile_val handles floats fine" do
    assert DiceStats.percentile_val_cell(100.0) == expected_coloured_cell( 100.0, "#000000", "#86E3CE" ) 
    assert DiceStats.percentile_val_cell(76.0) == expected_coloured_cell( 76.0, "#000000", "#86E3CE" ) 
    assert DiceStats.percentile_val_cell(75.0) == expected_coloured_cell( 75.0, "#000000", "#86E3CE" ) 
    assert DiceStats.percentile_val_cell(74.0) == expected_coloured_cell( 74.0, "#000000", "#D0E6A5" ) 
    assert DiceStats.percentile_val_cell(50.0) == expected_coloured_cell( 50.0, "#000000", "#D0E6A5" ) 
    assert DiceStats.percentile_val_cell(25.0) == expected_coloured_cell( 25.0, "#000000", "#FFDD94" ) 
    assert DiceStats.percentile_val_cell(0.0) == expected_coloured_cell( 0.0, "#000000", "#FA897B" ) 
  end

end
