=begin
  class JCPlayer
      implements the necessary public methods needed to launch a game of battleship
=end
class JCPlayer

  def initialize()
    @player_name = "JC Bermudez"

    @boardmng = BoardManager::new()
    @shipsmng = ShipsManager::new(@boardmng)
    @shootingmng = ShootingManager::new(@boardmng)
  end

  def name
    return @player_name
  end

  def new_game
    return @shipsmng.generate_ships_locations()
  end

  def take_turn(state, ships_remaining)
    return @shootingmng.best_shot(state)
  end

  #-- BEGING OF NESTED CLASSES
  class BoardManager
    def initialize()
      @grid_dimensions = [10, 10]
    end

    attr_reader(:grid_dimensions)

    def out_of_borders?(x,y)
      if x < 0 || x >= @grid_dimensions[0] ||
         y < 0 || y >= @grid_dimensions[1]
        return true
      else
        return false
      end
    end

    def step_through(state, row, col, delta_x, delta_y)
      #-- recursively find the next :hit or :unknown cell
      if ! out_of_borders?(col+delta_x, row+delta_y)
        if state[row+(delta_y)][col+(delta_x)] == :hit
          return step_through(state, row+delta_y, col+delta_x, delta_x, delta_y)
        elsif state[row+(delta_y)][col+(delta_x)] == :unknown
          return [col+(delta_x), row+(delta_y)]
        end
      end
      #-- all cells found are prior :miss-es
      return []
    end

  end #--END OF NESTED CLASS BoardManager

  class ShootingManager
    def initialize(boardMngr)
      @shots_fired = []
      @hits = []
      @boardmng = boardMngr
      @spiral_burst_path = generate_burst_path(4, 4)
    end

    attr_reader(:hits)

    def generate_burst_path(from_x, from_y)
      path = []
      distance_from_init = Range.new(1, 5)
      distance_from_init.step do |dist|
        [[1, 0], [0, 1], [-1, 0], [0, -1]].each do |delta|
          if dist > 1
            if delta[0] != 0
              if delta[0] == 1
                range = Range.new((delta[0]*dist*-1)+1, (delta[0]*dist-1))
              elsif delta[0] == -1
                range = Range.new((delta[0]*dist)+1, (delta[0]*dist*-1)-1)
              end
              range.step(2) do |pos|
                x = dist*delta[0]
                y = pos
                path << [x+from_x, y+from_y]
              end
            else
              if delta[1] == 1
                range = Range.new((delta[1]*dist*-1)+1, (delta[1]*dist-1))
              elsif delta[1] == -1
                range = Range.new((delta[1]*dist)+1, (delta[1]*dist*-1)-1)
              end
              range.step(2) do |pos|
                x = pos
                y = dist*delta[1]
                path << [x+from_x, y+from_y]
              end
            end
          else
            x = delta[0]
            y = delta[1]
            path << [x+from_x, y+from_y]
          end
        end
      end

      path.each do |pos|
        if @boardmng.out_of_borders?(pos[0], pos[1])
          path.delete(pos)
        end
      end

      return path.reverse
    end

    def best_shot(state)
      #-- inspect the state taking note of any new hit
      find_existing_hits(state)

      pos = []

      #-- looks for a possible hit adjacent to any of the prior hit cells
      pos = adjacent_shot(state)

      #-- if no move was possible, try a spiral-burst path
      if pos == []
        pos = spiral_burst_shot()
      #-- finally try any random alternative
        if pos == []
          pos = random_shot(state)
        end
      end

      log_shot(pos)
      return pos
    end

    def find_existing_hits(state)
      #-- go over the board and validate if last shot was a hit
      state.each_with_index do |row, row_index|
        row.each_with_index do |col, col_index|
          if col == :hit && @hits.find_index([col_index, row_index]) == nil
            @hits << [col_index, row_index]
          end
        end
      end
    end

    def adjacent_shot(state)
      pos = []

      if hits.length() > 2 && adjacent_pos?(hits[-2], hits[-1])
        delta = [hits[-1][0]-hits[-2][0], hits[-1][1]-hits[-2][1]]
        pos = [hits[-1][0]+delta[0], hits[-1][1]+delta[1]]
        if ! @boardmng.out_of_borders?(pos[0], pos[1]) &&
           ! @shots_fired.include?(pos)
          return pos
        end
      end

      #-- look for a cell adjacent to an existing hit
      hits.reverse.each do |ship_pos|
        [[1, 0], [0, 1], [-1, 0], [0, -1]].each do |delta_xy|
          pos = @boardmng.step_through(state, ship_pos[1], ship_pos[0], delta_xy[0], delta_xy[1])
          if pos != []
            return pos
          end
        end

      end

      return pos
    end

    def adjacent_pos?(cell1, cell2)
      [[1,0], [0, 1], [-1, 0], [0, -1]].each do |delta|
        if cell1[0]+delta[0] == cell2[0] ||
           cell1[1]+delta[1] == cell2[1]
          return true
        end
      end
      return false
    end

    def spiral_burst_shot()
      pos = []

      if ! @spiral_burst_path.empty?()
        pos = @spiral_burst_path.pop()
  
        while @shots_fired.include?(pos)
          if ! @spiral_burst_path.empty?()
            pos = @spiral_burst_path.pop()
          else
            break
          end
        end

      end

      return pos
    end

    def random_shot(state)
      pos = [rand(10), rand(10)]
      while @shots_fired.include?(pos) 
        pos = [rand(10), rand(10)]
      end

      return pos
    end

    def log_shot(shot_pos)
      @shots_fired << shot_pos
    end

  end #--END OF NESTED CLASS ShootingManager

  class ShipsManager
    def initialize(boardMngr)
      @ship_sizes = [5, 4, 3, 3, 2]
      @ships_locations = []
      @boardmng = boardMngr
    end

    def generate_ships_locations
      #-- generate the ship locations by ship's size
      @ship_sizes.all? do |size|

        #-- choose an orientation at random
        orientation = [:across, :down][rand(2)]
        valid_position = false

        while valid_position == false do
          #-- choose a xy position at random
          xy_pos = [rand(10), rand(10)]

          #-- make sure it doesn't go beyond borders and it's not overlapping existing ships
          if orientation == :across && 
              xy_pos[0]+size < @boardmng.grid_dimensions()[0] && 
              !overlap?(xy_pos, size, orientation) &&
              !collide?(xy_pos, size, orientation)

            valid_position = true

          elsif orientation == :down && 
              xy_pos[1]+size < @boardmng.grid_dimensions()[1] &&
              !overlap?(xy_pos, size, orientation) &&
              !collide?(xy_pos, size, orientation)

            valid_position = true

          end
        end    

        @ships_locations << [xy_pos[0], xy_pos[1], size, orientation]
      end

      return @ships_locations
    end

    #-- returns an array of [x,y]-arrays to conviently
    #-- depict where a ship is located
    def to_coordinates(x, y, size, orientation)
      coords = []

      if orientation == :across
        size.times do |n|
          coords << [x+n, y]  
        end
      elsif orientation == :down
        size.times do |n|
          coords << [x, y+n]
        end
      end

      return coords
    end

    #-- make sure a possible new ship's location will not overlap
    #-- the position of any of the existing ships
    def overlap?(xy_position, size, orientation)
      overlapping = false

      possible_new_ship_coords = to_coordinates(xy_position[0], xy_position[1], size, orientation)

      @ships_locations.map do |ship_location|
        existing_ship_coords = to_coordinates(ship_location[0], ship_location[1], ship_location[2], ship_location[3])

        #-- examine each coordinate of the existing ship versus each
        #-- coordinate of the new possible one
        if existing_ship_coords.any? { |e_coord| possible_new_ship_coords.any? { |n_coord| n_coord == e_coord } }
          overlapping = true
          break
        end
      end

      return overlapping
    end

    def collide?(xy_position, size, orientation)
      is_adjacent = false

      possible_new_ship_coords = to_coordinates(xy_position[0], xy_position[1], size, orientation)

      @ships_locations.each do |ship_location|
        existing_ship_coords = to_coordinates(ship_location[0], ship_location[1], ship_location[2], ship_location[3])
        #-- examine each coordinate of the existing ship versus each
        #-- coordinate of the new possible one
        [[1, 0], [0, 1], [-1, 0], [0, -1]].each do |delta_xy|
          existing_ship_coords.each do |e_coord|
            if possible_new_ship_coords.include?([e_coord[0]+delta_xy[0], e_coord[1]+delta_xy[1]])
              is_adjacent = true
            end
          end
        end
      end

      return is_adjacent
    end

  end #--END OF NESTED CLASS ShipsManager

end #-- END OF CLASS JCPlayer

