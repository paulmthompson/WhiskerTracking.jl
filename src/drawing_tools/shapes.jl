
#=
Draw arrow at point (x_b,y_b) with length m at angle a
=#

function draw_arrow(ctx,x_b,y_b,m,a,mycolor=(1,1,1))

    set_source_rgb(ctx,mycolor...)

    move_to(ctx,x_b,y_b)

    x_f = m * cos(a)
    y_f = m * sin(a)
    line_to(ctx,x_f,y_f)

    stroke(ctx)
end
