MODULE TIGHT_BINDING
  USE CONSTANTS, only: pi,pi2,xi,one,zero
  USE IOTOOLS, only:free_unit,reg,txtfy
  USE MATRIX, only: matrix_diagonalize
  USE COLORS
  !USE FT_TIGHT_BINDING
  implicit none
  private

  interface write_hk_w90
     module procedure write_hk_w90_,write_hk_w90__
  end interface write_hk_w90

  public :: indx2ix,indx2iy,indx2iz
  public :: coord2indx
  public :: indx2coord
  public :: kgrid
  public :: kgrid_from_path
  public :: build_hk_model
  public :: write_hk_w90
  public :: read_hk_w90
  public :: solve_along_BZpath
  public :: write_hloc
  public :: read_hloc

  public :: shrink_Hkr
  public :: expand_Hkr

  !public :: dft_hk_model
  !public :: dft_hk_path

  public :: lat_orb2lo

  !Some special points in the BZ:
  !we do everything in 3d.
  real(8),dimension(3),public,parameter :: kpoint_gamma=[0,0,0]*pi
  real(8),dimension(3),public,parameter :: kpoint_x1=[1,0,0]*pi
  real(8),dimension(3),public,parameter :: kpoint_x2=[0,1,0]*pi
  real(8),dimension(3),public,parameter :: kpoint_x3=[0,0,1]*pi
  real(8),dimension(3),public,parameter :: kpoint_m1=[1,1,0]*pi
  real(8),dimension(3),public,parameter :: kpoint_m2=[0,1,1]*pi
  real(8),dimension(3),public,parameter :: kpoint_m3=[1,0,1]*pi
  real(8),dimension(3),public,parameter :: kpoint_r=[1,1,1]*pi

contains


  function indx2ix(ik,ndim) result(ix)
    integer              :: ik
    integer              :: ix
    integer              :: nx_,ny_,nz_
    integer,dimension(3) :: ndim
    nx_=ndim(1)
    ny_=ndim(2)
    nz_=ndim(3)
    ix=int(ik-1)/ny_/nz_+1
  end function indx2ix

  function indx2iy(ik,ndim) result(iy)
    integer              :: ik
    integer              :: iy
    integer              :: nx_,ny_,nz_
    integer,dimension(3) :: ndim
    nx_=ndim(1)
    ny_=ndim(2)
    nz_=ndim(3)
    iy=mod(int(ik-1)/nz_,ny_)+1
  end function indx2iy

  function indx2iz(ik,ndim) result(iz)
    integer              :: ik
    integer              :: iz
    integer              :: nx_,ny_,nz_
    integer,dimension(3) :: ndim
    nx_=ndim(1)
    ny_=ndim(2)
    nz_=ndim(3)
    iz=mod(ik-1,nz_)+1
  end function indx2iz

  subroutine coord2indx(ik,ix,iy,iz,ndim)
    integer              :: ix,iy,iz
    integer,dimension(3) :: ndim
    integer              :: nx,ny,nz
    integer              :: ik
    nx=ndim(1)
    ny=ndim(2)
    nz=ndim(3)
    ik = (ix-1)*ny*nz+(iy-1)*nz+iz
  end subroutine coord2indx

  subroutine indx2coord(ik,ix,iy,iz,ndim)
    integer              :: ix,iy,iz
    integer,dimension(3) :: ndim
    integer              :: ik
    ix=indx2ix(ik,ndim)
    iy=indx2iy(ik,ndim)
    iz=indx2iz(ik,ndim)
  end subroutine indx2coord

  function kgrid(Nk,start,len)
    integer               :: Nk,i
    real(8),optional      :: start,len
    real(8)               :: start_,len_
    real(8),dimension(Nk) :: kgrid
    start_=-pi ;if(present(start))start_=start
    len_=2d0*pi;if(present(len))len_=len
    do i=1,Nk
       kgrid(i) = start_ + len_*(i-1)/Nk
    enddo
  end function kgrid

  function kgrid_from_path(kpath,Npts,Nk,dim) result(kxpath)
    real(8),dimension(Npts,3)      :: kpath
    real(8),dimension((Npts-1)*Nk) :: kxpath
    real(8),dimension(3)           :: kstart,kstop,kpoint,kdiff
    integer                        :: ipts,ik,ic,dim,Nk,Npts
    if(dim>3)stop "error kigrid_from_path: dim > 3"
    ic=0
    do ipts=1,Npts-1
       kstart = kpath(ipts,:)
       kstop  = kpath(ipts+1,:)
       kdiff  = (kstop-kstart)/dble(Nk)
       do ik=1,Nk
          ic=ic+1
          kpoint = kstart + (ik-1)*kdiff
          kxpath(ic)=kpoint(dim)
       enddo
    enddo
  end function kgrid_from_path







  function build_hk_model(Nk,Norb,hk_model,kxgrid,kygrid,kzgrid) result(Hk)
    integer                         :: Norb
    integer                         :: Nk,Nkx,Nky,Nkz
    integer                         :: ik,ix,iy,iz
    real(8),dimension(:)            :: kxgrid,kygrid,kzgrid
    real(8)                         :: kx,ky,kz
    complex(8),dimension(Nk,Norb,Norb) :: hk
    interface 
       function hk_model(kpoint,N)
         real(8),dimension(:)       :: kpoint
         complex(8),dimension(N,N)  :: hk_model
       end function hk_model
    end interface
    Nkx = size(kxgrid)
    Nky = size(kygrid)
    Nkz = size(kzgrid)
    if(Nk /= Nkx*Nky*Nkz) stop "build_hk_model: error in dimension Nk"
    do ik=1,Nk
       call indx2coord(ik,ix,iy,iz,[Nkx,Nky,Nkz])
       kx=kxgrid(ix)
       ky=kygrid(iy)
       kz=kzgrid(iz)
       Hk(ik,:,:) = hk_model([kx,ky,kz],Norb)
    enddo
  end function build_hk_model






  subroutine write_hk_w90_(file,Norb,Np,Nineq,hk_model,kxgrid,kygrid,kzgrid)
    character(len=*)                :: file
    integer                         :: Norb,Nd,Np,Nineq
    integer                         :: Nktot,Nkx,Nky,Nkz,unit
    integer                         :: ik,ix,iy,iz,iorb,jorb
    real(8),dimension(:)            :: kxgrid,kygrid,kzgrid
    real(8)                         :: kx,ky,kz
    complex(8),dimension(Norb,Norb) :: hk
    interface 
       function hk_model(kpoint,N)
         real(8),dimension(:)       :: kpoint
         complex(8),dimension(N,N)  :: hk_model
       end function hk_model
    end interface
    unit=free_unit()
    Nkx = size(kxgrid)
    Nky = size(kygrid)
    Nkz = size(kzgrid)
    Nktot = Nkx*Nky*Nkz
    Nd = Norb-Np    
    open(unit,file=reg(file))
    write(unit,'(1A1,1A12,1x,3(A2,1x))')"#",reg(txtfy(Nktot)),reg(txtfy(Nd)),reg(txtfy(Np)),reg(txtfy(Nineq))
    do ik=1,Nktot
       call indx2coord(ik,ix,iy,iz,[Nkx,Nky,Nkz])
       kx=kxgrid(ix)
       ky=kygrid(iy)
       kz=kzgrid(iz)
       Hk(:,:) = hk_model([kx,ky,kz],Norb)
       write(unit,"(3(F15.9,1x))")kx,ky,kz
       do iorb=1,Norb
          write(unit,"(20(2F15.9,1x))")(Hk(iorb,jorb),jorb=1,Norb)
       enddo
    enddo
  end subroutine write_hk_w90_

  subroutine write_hk_w90__(file,Norb,Np,Nineq,hk,kxgrid,kygrid,kzgrid)
    character(len=*)                :: file
    integer                         :: Norb,Nd,Np,Nineq
    integer                         :: Nktot,Nkx,Nky,Nkz,unit
    integer                         :: ik,ix,iy,iz,iorb,jorb
    real(8),dimension(:)            :: kxgrid,kygrid,kzgrid
    real(8)                         :: kx,ky,kz
    complex(8),dimension(:,:,:)     :: Hk    
    unit=free_unit()
    Nkx = size(kxgrid)
    Nky = size(kygrid)
    Nkz = size(kzgrid)
    Nktot = Nkx*Nky*Nkz
    if(size(Hk,1)/=Nktot)stop "write_hk_f90: error in dimension Hk,1"
    if(size(Hk,2)/=Norb)stop "write_hk_f90: error in dimension Hk,2"
    if(size(Hk,3)/=Norb)stop "write_hk_f90: error in dimension Hk,3"
    Nd = Norb-Np    
    open(unit,file=reg(file))
    write(unit,'(1A1,1A12,1x,3(A2,1x))')"#",reg(txtfy(Nktot)),reg(txtfy(Nd)),reg(txtfy(Np)),reg(txtfy(Nineq))
    do ik=1,Nktot
       call indx2coord(ik,ix,iy,iz,[Nkx,Nky,Nkz])
       kx=kxgrid(ix)
       ky=kygrid(iy)
       kz=kzgrid(iz)
       write(unit,"(3(F15.9,1x))")kx,ky,kz
       do iorb=1,Norb
          write(unit,"(20(2F15.9,1x))")(Hk(ik,iorb,jorb),jorb=1,Norb)
       enddo
    enddo
  end subroutine write_hk_w90__

  subroutine read_hk_w90(file,Norb,Np,Nineq,hk,kxgrid,kygrid,kzgrid)
    character(len=*)            :: file
    integer                     :: Norb,Nd,Np,Nineq
    integer                     :: Nktot,Nk_,Nkx,Nky,Nkz,unit
    integer                     :: ik,ix,iy,iz,iorb,jorb
    real(8),dimension(:)        :: kxgrid,kygrid,kzgrid
    real(8)                     :: kx,ky,kz
    logical                     :: ioexist
    complex(8),dimension(:,:,:) :: Hk
    character(len=1)            :: achar
    unit=free_unit()
    inquire(file=reg(file),exist=ioexist)
    if(.not.ioexist)then
       write(*,*)"can not find file:"//reg(file)
       stop
    endif
    open(unit,file=reg(file))
    Nkx = size(kxgrid)
    Nky = size(kygrid)
    Nkz = size(kzgrid)
    Nktot = Nkx*Nky*Nkz
    read(unit,'(1A1,I12,1x,3(I2,1x))')achar,Nk_,Nd,Np,Nineq
    if(Norb/=(Nd+Np))stop "read_hk_f90: error in number Norb"
    if(Nk_/=Nktot)stop "read_hk_f90: error in number of k-points: check kgrids and the header"
    if(size(Hk,1)/=Nktot)stop "read_hk_f90: error in dimension Hk,1"
    if(size(Hk,2)/=Norb)stop "read_hk_f90: error in dimension Hk,2"
    if(size(Hk,3)/=Norb)stop "read_hk_f90: error in dimension Hk,3"
    do ik=1,Nktot
       call indx2coord(ik,ix,iy,iz,[Nkx,Nky,Nkz])
       read(unit,"(3(F15.9,1x))")kx,ky,kz
       kxgrid(ix)=kx
       kygrid(iy)=ky
       kzgrid(iz)=kz
       do iorb=1,Norb
          read(unit,"(20(2F15.9,1x))")(Hk(ik,iorb,jorb),jorb=1,Norb)
       enddo
    enddo
  end subroutine read_hk_w90










  subroutine solve_along_BZpath(Nk,kpath,Norb,hk_model,colors_name,points_name,file)
    integer                                   :: Nk
    integer                                   :: Norb
    real(8),dimension(:,:)                    :: kpath
    character(len=*),dimension(Norb)          :: colors_name
    character(len=*),dimension(size(kpath,1)) :: points_name
    character(len=*),optional                 :: file
    character(len=256)                        :: file_,xtics
    integer                                   :: Npts
    integer                                   :: ipts,ik,ic,unit,u1,u2,iorb
    real(8),dimension(size(kpath,2))          :: kstart,kstop,kpoint,kdiff
    real(8)                                   :: eval(Norb),coeff(Norb)
    complex(8)                                :: h(Norb,Norb)
    type(rgb_color)                           :: corb(Norb),c(Norb)
    interface 
       function hk_model(kpoint,N)
         real(8),dimension(:)                 :: kpoint
         complex(8),dimension(N,N)            :: hk_model
       end function hk_model
    end interface
    file_="Eigenbands.tb";if(present(file))file_=file
    Npts=size(kpath,1)
    ic = 0
    do iorb=1,Norb
       corb(iorb) = pick_color(colors_name(iorb))
    enddo
    unit=free_unit()
    open(unit,file=reg(file_))
    do ipts=1,Npts-1
       kstart = kpath(ipts,:)
       kstop  = kpath(ipts+1,:)
       kdiff  = (kstop-kstart)/dble(Nk)
       do ik=1,Nk
          ic=ic+1
          kpoint = kstart + (ik-1)*kdiff
          h = hk_model(kpoint,Norb)
          call matrix_diagonalize(h,Eval)
          do iorb=1,Norb
             coeff(:)=h(iorb,:)*conjg(h(iorb,:))
             c(iorb) = coeff.dot.corb
          enddo
          write(unit,'(I12,100(F18.12,I18))')ic,(Eval(iorb),rgb(c(iorb)),iorb=1,Norb)
       enddo
    enddo
    close(unit)
    xtics=' '
    do ipts=1,Npts-1
       xtics=reg(xtics)//"'"//reg(points_name(ipts))//"'"//reg(txtfy((ipts-1)*Nk))//","
    enddo
    xtics=reg(xtics)//"'"//reg(points_name(Npts))//"'"//reg(txtfy((Npts-1)*Nk))//""
    open(unit,file=reg(file_)//".gp")
    write(unit,*)"gnuplot -persist << EOF"
    write(unit,*)"set term wxt"
    write(unit,*)"set nokey"
    write(unit,*)"set xtics ("//reg(xtics)//")"
    write(unit,*)"set grid noytics xtics"
    write(unit,*)"plot '"//reg(file_)//"' u 1:2:3 w l lw 3 lc rgb variable"
    do iorb=2,Norb
       u1=2+(iorb-1)*2
       u2=3+(iorb-1)*2
       write(unit,*)"rep '"//reg(file_)//"' u 1:"&
            //reg(txtfy(u1))//":"//reg(txtfy(u2))//" w l lw 3 lc rgb variable"
    enddo
    write(unit,*)"#set term png size 1920,1280"
    write(unit,*)"#set out '"//reg(file_)//".png'"
    write(unit,*)"#rep"
    write(unit,"(A)")"EOF"
    close(unit)
    call system("chmod +x "//reg(file_)//".gp")
  end subroutine solve_along_BZpath


  subroutine write_hloc(hloc,file)
    complex(8),dimension(:,:) :: Hloc
    character(len=*)          :: file
    integer                   :: iorb,jorb,Ni,Nj,unit
    unit=free_unit()   
    open(unit,file=reg(file))
    Ni=size(Hloc,1)
    Nj=size(Hloc,2)
    do iorb=1,Ni
       write(unit,"(90F21.12)")(dreal(Hloc(iorb,jorb)),jorb=1,Nj)
    enddo
    write(unit,*)""
    do iorb=1,Ni
       write(unit,"(90F21.12)")(dimag(Hloc(iorb,jorb)),jorb=1,Nj)
    enddo
    close(unit)
  end subroutine write_hloc

  subroutine read_hloc(hloc,file)
    complex(8),dimension(:,:) :: Hloc
    character(len=*)          :: file
    integer                   :: iorb,jorb,Ni,Nj,unit
    real(8),dimension(size(Hloc,1),size(Hloc,2)) :: reHloc,imHloc
    unit=free_unit()   
    open(unit,file=reg(file))
    Ni=size(Hloc,1)
    Nj=size(Hloc,2)
    do iorb=1,Ni
       read(unit,"(90F21.12)")(reHloc(iorb,jorb),jorb=1,Nj)
    enddo
    write(unit,*)""
    do iorb=1,Ni
       read(unit,"(90F21.12)")(imHloc(iorb,jorb),jorb=1,Nj)
    enddo
    close(unit)
    Hloc = dcmplx(reHloc,imHloc)
  end subroutine read_hloc





  function shrink_Hkr(Hkr,Nlat,Nk,Norb) result(Hkr_)
    complex(8),dimension(Nlat,Nlat,Nk,Norb,Norb) :: Hkr
    integer                                      :: Norb,Nlat,Nk
    integer                                      :: io,jo,ilat,iorb,jorb,jlat,ik
    complex(8),dimension(Nlat*Norb,Nlat*Norb,Nk) :: Hkr_
    do ilat=1,Nlat
       do jlat=1,Nlat
          do iorb=1,Norb
             do jorb=1,Norb
                io=lat_orb2lo(ilat,iorb,Norb)
                jo=lat_orb2lo(jlat,jorb,Norb)
                do ik=1,Nk
                   Hkr_(io,jo,ik)=Hkr(ilat,jlat,ik,iorb,jorb)
                enddo
             enddo
          enddo
       enddo
    enddo
  end function shrink_Hkr

  function expand_Hkr(Hkr_,Nlat,Nk,Norb) result(Hkr)
    complex(8),dimension(Nlat,Nlat,Nk,Norb,Norb) :: Hkr
    integer                                      :: Norb,Nlat,Nk
    integer                                      :: io,jo,ilat,iorb,jorb,jlat,ik
    complex(8),dimension(Nlat*Norb,Nlat*Norb,Nk) :: Hkr_
    do ilat=1,Nlat
       do jlat=1,Nlat
          do iorb=1,Norb
             do jorb=1,Norb
                io=lat_orb2lo(ilat,iorb,Norb)
                jo=lat_orb2lo(jlat,jorb,Norb)
                do ik=1,Nk
                   Hkr(ilat,jlat,ik,iorb,jorb)=Hkr_(io,jo,ik)
                enddo
             enddo
          enddo
       enddo
    enddo
  end function expand_Hkr


  function lat_orb2lo(ilat,iorb,Norb) result(io)
    integer :: ilat,iorb,io,Norb
    io=(ilat-1)*Norb + iorb
  end function lat_orb2lo




END MODULE TIGHT_BINDING
