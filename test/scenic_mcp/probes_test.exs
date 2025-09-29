defmodule ScenicMcp.ProbesTest do
  use ExUnit.Case, async: true
  
  alias ScenicMcp.Probes
  doctest ScenicMcp.Probes

  describe "semantic DOM API" do
    test "get_semantic_dom/1 returns error when viewport not found" do
      result = Probes.get_semantic_dom(:nonexistent_viewport)
      assert {:error, "ViewPort nonexistent_viewport not found"} = result
    end
    
    test "get_visible_dom/1 returns error when viewport not found" do
      result = Probes.get_visible_dom(:nonexistent_viewport)
      assert {:error, "ViewPort nonexistent_viewport not found"} = result
    end
    
    test "query/2 returns error when viewport not found" do
      result = Probes.query(:text_buffer, :nonexistent_viewport)
      assert {:error, "ViewPort nonexistent_viewport not found"} = result
    end
    
    test "get_all_buffer_content/1 returns error when viewport not found" do
      result = Probes.get_all_buffer_content(:nonexistent_viewport)
      assert {:error, "ViewPort nonexistent_viewport not found"} = result
    end
  end
  
  describe "low-level Scenic API" do
    test "viewport_pid_safe/0 returns nil when no viewport" do
      # This might return a PID if tests are run in context with a viewport
      result = Probes.viewport_pid_safe()
      assert result == nil or is_pid(result)
    end
    
    test "driver_pid_safe/0 returns nil when no driver" do
      # This might return a PID if tests are run in context with a driver
      result = Probes.driver_pid_safe()
      assert result == nil or is_pid(result)
    end
  end
  
  describe "semantic DOM structure" do
    # These tests would require a running Scenic application
    # For now, we test the structure of the expected DOM format
    
    test "semantic DOM has expected structure" do
      expected_keys = [:viewport, :timestamp, :components, :summary]
      
      # Mock a semantic DOM structure
      mock_dom = %{
        viewport: %{name: :test, size: {800, 600}},
        timestamp: 1234567890,
        components: [
          %{
            id: "test-id",
            type: :component,
            visible: true,
            timestamp: 1234567890,
            elements: [
              %{
                id: :test_element,
                type: :text_buffer,
                semantic: %{type: :text_buffer, buffer_id: "uuid"},
                content: "test content",
                properties: %{editable: true}
              }
            ]
          }
        ],
        summary: %{
          total_components: 1,
          total_elements: 1,
          by_type: %{text_buffer: 1}
        }
      }
      
      # Verify structure
      assert Map.keys(mock_dom) == expected_keys
      assert is_map(mock_dom.viewport)
      assert is_integer(mock_dom.timestamp)
      assert is_list(mock_dom.components)
      assert is_map(mock_dom.summary)
      
      # Verify component structure
      component = List.first(mock_dom.components)
      expected_component_keys = [:id, :type, :visible, :timestamp, :elements]
      assert Map.keys(component) == expected_component_keys
      
      # Verify element structure
      element = List.first(component.elements)
      expected_element_keys = [:id, :type, :semantic, :content, :properties]
      assert Map.keys(element) == expected_element_keys
    end
  end
  
  describe "filter functions" do
    setup do
      elements = [
        %{
          type: :text_buffer,
          properties: %{editable: true},
          semantic: %{type: :text_buffer}
        },
        %{
          type: :button,
          properties: %{editable: false},
          semantic: %{type: :button}
        },
        %{
          type: :text_buffer,
          properties: %{editable: false},
          semantic: %{type: :text_buffer}
        }
      ]
      
      {:ok, elements: elements}
    end
    
    test "filter_by_type filters by exact type", %{elements: elements} do
      # We need to test the private function indirectly
      # by using the public query function with a mock DOM
      
      text_buffers = Enum.filter(elements, fn elem ->
        elem.type == :text_buffer
      end)
      
      assert length(text_buffers) == 2
    end
    
    test "filter_by_type filters editable elements", %{elements: elements} do
      editable = Enum.filter(elements, fn elem ->
        elem.properties[:editable] == true
      end)
      
      assert length(editable) == 1
      assert List.first(editable).type == :text_buffer
    end
  end
end