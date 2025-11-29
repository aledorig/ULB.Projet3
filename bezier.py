import matplotlib.pyplot as plt
import random as rd

# generate random points list
# implement matplotlib function draw to test
# implement bezier curve (quad and cubic)
# implement bspline curve

def generate_random_points(length:int, range_x : tuple[int,int], range_y : tuple[int, int]) -> tuple[list[int], list[int]]:
    return rd.sample(range(range_x[0], range_x[1]), length), rd.sample(range(range_y[0], range_y[1]), length)

def compute_quad_bezier_segment(P0 : tuple[int, int], P1 : tuple[int, int], P2 : tuple[int, int]) -> tuple[list[float], list[float]]:
    # should compute B(t)...
    # hard coded step
    curve_x, curve_y = [], []
    step = 20
    for i in range(step + 1):
        
        t = i / step
        
        # https://en.wikipedia.org/wiki/B%C3%A9zier_curve   
        x = (1-t)**2 * P0[0] + 2*(1-t)*t * P1[0] + t**2 * P2[0]
        y = (1-t)**2 * P0[1] + 2*(1-t)*t * P1[1] + t**2 * P2[1]
        
        curve_x.append(x)
        curve_y.append(y)
    
    return curve_x, curve_y

def compute_cubic_bezier_segment(P0 : tuple[int, int], 
                                 P1 : tuple[int, int], 
                                 P2 : tuple[int, int], 
                                 P3 : tuple[int, int]) -> tuple[list[float], list[float]]:
    # should compute B(t)...
    # hard coded step
    curve_x, curve_y = [], []
    step = 20
    for i in range(step + 1):
        
        t = i / step
        
        # https://en.wikipedia.org/wiki/B%C3%A9zier_curve   
        x = (1-t)**3 * P0[0] + 3*(1-t)**2 * t * P1[0] + 3*(1-t)*t**2 * P2[0] + t**3 * P3[0]
        y = (1-t)**3 * P0[1] + 3*(1-t)**2 * t * P1[1] + 3*(1-t)*t**2 * P2[1] + t**3 * P3[1]
        
        curve_x.append(x)
        curve_y.append(y)
    
    return curve_x, curve_y

def generate_bezier_curve(points : tuple[list[int], list[int]]) -> tuple[list[float], list[float]]:
    curve = [], []
    
    for i in range(0, len(points[0]) - 3, 3):
        
        segment = compute_cubic_bezier_segment(
            (points[0][i], points[1][i]),
            (points[0][i+1], points[1][i+1]),
            (points[0][i+2], points[1][i+2]),
            (points[0][i+3], points[1][i+3])
        )
        
        curve[0].extend(segment[0])
        curve[1].extend(segment[1])
        
    return curve

def compute_knot_vector(n: int, p: int) -> list[float]:
    knots = []
    
    # first p+1 knots
    knots.extend([0.0] * (p+1))
    
    # internal knots
    for i in range(1, (n-p) + 1):
        knots.append(i / ((n-p) + 1))
    
    # last p+1 knots
    knots.extend([1.0] * (p+1))
    
    return knots

def basis(i : int, j : int, t : float, knots : list[float] = []) -> float:
    """
    Important TODO handling recursive 
    """
    
    # Base case
    if j == 0:
        if knots[i] <= t < knots[i + 1]:
            return 1.0
        elif t == knots[-1] and knots[i] <= t <= knots[i + 1]:
            return 1.0
        else:
            return 0.0
        
    # Respecting domain by checking denominator for seg 1
    den_seg_1 = knots[i+j] - knots[i]
    seg_1 = 0.0
    if (den_seg_1 != 0):
        seg_1 = ((t - knots[i]) / den_seg_1) * basis(i, j-1, t, knots)
         
    # Respecting domain by checking denominator for seg 2
    den_seg_2 = knots[i+j+1] - knots[i+1]
    seg_2 = 0.0
    if (den_seg_2 != 0):
        seg_2 = ((knots[i+j+1] - t) / den_seg_2) * basis(i+1, j-1, t, knots)
    
    return seg_1 + seg_2

def compute_point_on_bspline(t:float, control_points: tuple[list, list], p:int, knots:list[float]) -> tuple[float, float]:
    n = len(control_points[0]) - 1
    x, y = 0.0, 0.0
    
    for i in range(n + 1):
        b = basis(i, p, t, knots)
        x += control_points[0][i] * b
        y += control_points[1][i] * b
    
    return x, y

def generate_bspline_curve(control_points: tuple[list[float], list[float]], p:int, steps:int) -> tuple[list[float], list[float]]:
    """
    Important control_points[0] and control_points[1] should be the same size
    The size of control_points[0] greater than p (the degree)
    
    https://mathworld.wolfram.com/B-Spline.html
    https://www.geeksforgeeks.org/computer-graphics/b-spline-curve-in-computer-graphics/
    """
    
    knots = compute_knot_vector(len(control_points[0])-1, p)
    
    curve_x, curve_y = [], []
    
    for i in range(steps+1):
        t = i/steps
        x, y = compute_point_on_bspline(t, control_points, p, knots)
        
        curve_x.append(x)
        curve_y.append(y)
    
    return curve_x, curve_y

def main():
    
    # Generate 7 coherent control points that form a smooth path
    c_x = [-80, -50, -20, 0, 30, 60, 80]
    c_y = [-40, 30, -20, 50, 20, -30, 40]
    
    x, y = generate_bspline_curve((c_x, c_y), 2, 1000)
    
    plt.xlim((-100, 100))
    plt.ylim((-100, 100))
    
    plt.plot(c_x, c_y, 'ro-', label='Control points')
    plt.plot(x, y, 'b-', label='Bezier curve', linewidth=3)
    plt.ylabel('curve')
    plt.show()
    
    return

if __name__ == "__main__":
    main()