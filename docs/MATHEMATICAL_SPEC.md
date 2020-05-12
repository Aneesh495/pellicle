# Pellicle Mathematical & Algorithmic Derivations

## 1. Heterodyne Laser Interferometry & Metrology

The optical displacement $d$ of a moving wafer chuck retroreflector mirror is measured by detecting the phase change $\Delta \phi$ between reference and measurement optical frequencies:

$$d = \frac{\lambda_0}{2 \cdot n_{\text{air}}(T, P, H, CO_2)} \cdot \left( N + \frac{\Delta \phi}{2\pi} \right)$$

where:
- $\lambda_0 = 632.816460\text{ nm}$ is the vacuum wavelength of a stabilized Helium-Neon (HeNe) laser source.
- $N \in \mathbb{Z}$ is the integer fringe counter accumulated by quadrature phase edge transitions.
- $\Delta \phi \in [0, 2\pi)$ is the fractional phase angle unwrapped from optical receiver in-phase ($I$) and quadrature ($Q$) signals.
- $n_{\text{air}}$ is the dynamic refractive index of cleanroom air.

### 1.1 The Updated Edlen Formula
Under the 1994 Birch and Downs standard formulation, the refractivity of standard air $(T = 15^\circ\text{C}, P = 101325\text{ Pa}, \text{dry air}, 450\text{ ppm } CO_2)$ at wavenumber $\sigma = 1 / \lambda_{\mu m}$ is:

$$(n_s - 1) \times 10^8 = 8342.54 + \frac{2406147}{130 - \sigma^2} + \frac{15998}{38.9 - \sigma^2}$$

Correction for ambient $CO_2$ abundance $x$ (in ppm):

$$(n_x - 1) = (n_s - 1) \cdot \left[ 1 + 0.534 \times 10^{-6} \cdot (x - 450) \right]$$

Correction for temperature $T$ (in $^\circ\text{C}$) and barometric pressure $P$ (in $\text{Pa}$):

$$(n_{tp} - 1) = (n_x - 1) \cdot \frac{P}{96095.43} \cdot \frac{1 + 10^{-8} (0.601 - 0.00972 T) P}{1 + 0.003661 T}$$

Correction for partial water vapor pressure $f$ (in $\text{Pa}$), derived via Sonntag saturation equations:

$$(n_{tpf} - n_{tp}) = - f \cdot (3.7345 - 0.0401 \sigma^2) \times 10^{-10}$$

The final environmental index is $n_{\text{air}} = 1 + (n_{tpf} - 1)$.

## 2. 7th-Order Jerk-Continuous Trajectory Planning

To avoid exciting structural resonant modes of the wafer chuck mirror block ($f_{\text{res}} \approx 180\text{ Hz}$ and $450\text{ Hz}$), stage motion profiles follow a $C^3$-continuous 7th-order polynomial with zero boundary derivatives up to third order.

Let normalized time be $\tau = \frac{t - t_0}{T} \in [0, 1]$.
The normalized position polynomial is:

$$P(\tau) = 35 \tau^4 - 84 \tau^5 + 70 \tau^6 - 20 \tau^7$$

### Boundary Constraints
- Position: $P(0) = 0$, $P(1) = 1$
- Velocity: $P'(0) = 0$, $P'(1) = 0$
- Acceleration: $P''(0) = 0$, $P''(1) = 0$
- Jerk: $P'''(0) = 0$, $P'''(1) = 0$

### Derivative Profiles
$$\dot{s}(\tau) = \frac{\Delta s}{T} \cdot (140 \tau^3 - 420 \tau^4 + 420 \tau^5 - 140 \tau^6) = \frac{\Delta s}{T} \cdot 140 \tau^3 (1 - \tau)^3$$
$$\ddot{s}(\tau) = \frac{\Delta s}{T^2} \cdot (420 \tau^2 - 1680 \tau^3 + 2100 \tau^4 - 840 \tau^5)$$
$$s^{(3)}(\tau) = \frac{\Delta s}{T^3} \cdot (840 \tau - 5040 \tau^2 + 8400 \tau^3 - 4200 \tau^4)$$

Peak kinematic values:
- Maximum normalized velocity occurs at $\tau = 0.5$: $P'_{\max} = 2.1875$
- Maximum normalized acceleration occurs at $\tau = \frac{1}{2} \pm \frac{\sqrt{5}}{10} \approx 0.2764$: $P''_{\max} \approx 5.7735$
- Maximum normalized jerk occurs at $\tau \approx 0.106$: $P'''_{\max} \approx 13.125$

The minimum move duration $T$ required to satisfy physical stage limits is:

$$T_{\min} = \max\left( \frac{2.1875 |\Delta s|}{V_{\max}}, \sqrt{\frac{5.7735 |\Delta s|}{A_{\max}}}, \sqrt[3]{\frac{13.125 |\Delta s|}{J_{\max}}} \right)$$

## 3. Planar Motor Lorentz Actuator Decoupling

The 6-DoF stage is driven by 8 magnetic actuators:
- Coils 1 to 4: Horizontal planar Lorentz motors ($F_x, F_y, T_z$).
- Coils 5 to 8: Vertical voice-coil motors ($F_z, T_x, T_y$).

Given motor force constant $K_f = 18.5\text{ N/A}$ and actuator radius $R = 0.160\text{ m}$:

### Horizontal Planar Allocation:
$$I_1 = \frac{F_x}{2 K_f} + \frac{T_z}{4 K_f R}, \quad I_2 = \frac{F_x}{2 K_f} - \frac{T_z}{4 K_f R}$$
$$I_3 = \frac{F_y}{2 K_f} + \frac{T_z}{4 K_f R}, \quad I_4 = \frac{F_y}{2 K_f} - \frac{T_z}{4 K_f R}$$

### Vertical Levitation Allocation:
$$I_5 = \frac{F_z}{4 K_f} + \frac{T_y}{4 K_f R} + \frac{T_x}{4 K_f R}$$
$$I_6 = \frac{F_z}{4 K_f} - \frac{T_y}{4 K_f R} + \frac{T_x}{4 K_f R}$$
$$I_7 = \frac{F_z}{4 K_f} + \frac{T_y}{4 K_f R} - \frac{T_x}{4 K_f R}$$
$$I_8 = \frac{F_z}{4 K_f} - \frac{T_y}{4 K_f R} - \frac{T_x}{4 K_f R}$$

Total instantaneous Ohmic thermal power dissipation:

$$P_{\text{heat}} = R_{\text{coil}} \cdot \sum_{i=1}^8 I_i^2 \le 150.0\text{ W}$$

## 4. Slit Exposure Dynamics & Overlay Error Integration

During continuous scanning exposure across the optical illumination slit ($H_{\text{slit}} = 8.0\text{ mm}$), each point on the wafer integrates the instantaneous tracking error vector $\mathbf{e}(t) = \mathbf{x}_W(t) - \frac{1}{4} \mathbf{x}_R(t)$ over exposure transit time $T_{\text{exp}} = H_{\text{slit}} / v_{\text{scan}}$.

### Dynamic Moving Average (DMA):
$$\text{DMA}(\mathbf{e}) = \frac{1}{T_{\text{exp}}} \int_t^{t + T_{\text{exp}}} \mathbf{e}(\tau) \, d\tau \le 1.20\text{ nm}$$

### Moving Standard Deviation (MSD):
$$\text{MSD}(\mathbf{e}) = \sqrt{ \frac{1}{T_{\text{exp}}} \int_t^{t + T_{\text{exp}}} (\mathbf{e}(\tau) - \text{DMA}(\mathbf{e}))^2 \, d\tau } \le 1.80\text{ nm}$$

## 5. Wafer Topography Height Leveling

For $N$ confocal height measurement samples $(x_i, y_i, z_i)$, the best-fit leveling plane is:

$$z(x, y) = z_0 + R_x \cdot y - R_y \cdot x$$

Normal equations:

$$\begin{bmatrix}
\sum x_i^2 & \sum x_i y_i & \sum x_i \\
\sum x_i y_i & \sum y_i^2 & \sum y_i \\
\sum x_i & \sum y_i & N
\end{bmatrix}
\begin{bmatrix}
-R_y \\
R_x \\
z_0
\end{bmatrix}
=
\begin{bmatrix}
\sum x_i z_i \\
\sum y_i z_i \\
\sum z_i
\end{bmatrix}$$

Solved deterministically via Cramer's rule. The leveling plane is validated against the depth-of-focus tolerance: $\text{PV} \le 120.0\text{ nm}$.
