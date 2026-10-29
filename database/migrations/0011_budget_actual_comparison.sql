SET NOCOUNT ON;
SET XACT_ABORT ON;

/* CU-223. Reporte de sólo lectura; rollback: retirar el procedimiento. */
GO
CREATE OR ALTER PROCEDURE dbo.sp_BudgetComparison_Dashboard
 @Anio INT,@DepartamentoId INT=NULL,@Mes INT=NULL,@CategoriaId INT=NULL,@EstadoGasto NVARCHAR(30)=NULL,@Pagina INT=1,@TamanoPagina INT=20,@FechaNegocio DATE
AS
BEGIN
 SET NOCOUNT ON;
 IF @Anio NOT BETWEEN 2000 AND 2100 THROW 54400,N'Año inválido.',1;
 SET @Pagina=CASE WHEN @Pagina<1 THEN 1 ELSE @Pagina END;SET @TamanoPagina=CASE WHEN @TamanoPagina<1 THEN 20 WHEN @TamanoPagina>100 THEN 100 ELSE @TamanoPagina END;
 SELECT p.DepartamentoId,pd.CategoriaId,pd.Mes,pd.MontoAsignado INTO #B
 FROM dbo.PresupuestosAnuales p INNER JOIN dbo.PresupuestoDetalles pd ON pd.PresupuestoId=p.PresupuestoId
 WHERE p.Anio=@Anio AND p.Estado=N'Aprobado' AND p.Activo=1 AND(@DepartamentoId IS NULL OR p.DepartamentoId=@DepartamentoId)AND(@Mes IS NULL OR pd.Mes=@Mes)AND(@CategoriaId IS NULL OR pd.CategoriaId=@CategoriaId);
 SELECT * INTO #E FROM dbo.vw_OperatingExpenseImpact WHERE YEAR(FechaGasto)=@Anio AND Estado<>N'Anulado' AND(@DepartamentoId IS NULL OR DepartamentoId=@DepartamentoId)AND(@Mes IS NULL OR MONTH(FechaGasto)=@Mes)AND(@CategoriaId IS NULL OR CategoriaId=@CategoriaId)AND(@EstadoGasto IS NULL OR Estado=@EstadoGasto);
 DECLARE @anual DECIMAL(18,2)=(SELECT ISNULL(SUM(pd.MontoAsignado),0)FROM dbo.PresupuestosAnuales p JOIN dbo.PresupuestoDetalles pd ON pd.PresupuestoId=p.PresupuestoId WHERE p.Anio=@Anio AND p.Estado=N'Aprobado'AND p.Activo=1);
 DECLARE @budget DECIMAL(18,2)=(SELECT ISNULL(SUM(MontoAsignado),0)FROM #B),@registered DECIMAL(18,2)=(SELECT ISNULL(SUM(CASE WHEN Estado=N'Registrado'THEN Total ELSE 0 END),0)FROM #E),@approved DECIMAL(18,2)=(SELECT ISNULL(SUM(CASE WHEN Estado=N'Aprobado'THEN Total ELSE 0 END),0)FROM #E),@paid DECIMAL(18,2)=(SELECT ISNULL(SUM(CASE WHEN Estado=N'Pagado'THEN Total ELSE 0 END),0)FROM #E);
 DECLARE @real DECIMAL(18,2)=@approved+@paid,@elapsed INT=CASE WHEN @Anio<YEAR(@FechaNegocio)THEN 12 WHEN @Anio>YEAR(@FechaNegocio)THEN 0 ELSE MONTH(@FechaNegocio)END;
 SELECT @anual AnnualBudget,@budget FilteredBudget,@registered RegisteredExpense,@approved ApprovedExpense,@paid PaidExpense,@registered PendingExpense,@real RealExpense,@budget-@real Available,@real-@budget Variance,
  CAST(CASE WHEN @budget=0 THEN 0 ELSE @real/@budget*100 END AS DECIMAL(9,2))ExecutionPercent,CAST(CASE WHEN @elapsed=0 THEN 0 ELSE @real/@elapsed*12 END AS DECIMAL(18,2))AnnualProjection,
  (SELECT COUNT(*)FROM #E)ExpenseCount,(SELECT COUNT(*)FROM dbo.DepartamentosOperativos d WHERE d.Activo=1 AND(@DepartamentoId IS NULL OR d.DepartamentoId=@DepartamentoId)AND NOT EXISTS(SELECT 1 FROM dbo.PresupuestosAnuales p WHERE p.Anio=@Anio AND p.DepartamentoId=d.DepartamentoId AND p.Estado=N'Aprobado'AND p.Activo=1))DepartmentsWithoutBudget,
  (SELECT COUNT(*)FROM(SELECT c.CategoriaId FROM dbo.CategoriasGasto c OUTER APPLY(SELECT SUM(MontoAsignado)Budget FROM #B WHERE CategoriaId=c.CategoriaId)b OUTER APPLY(SELECT SUM(Total)Real FROM #E WHERE CategoriaId=c.CategoriaId AND Estado IN(N'Aprobado',N'Pagado'))e WHERE c.Activo=1 AND ISNULL(e.Real,0)>ISNULL(b.Budget,0))q)OverBudgetCategories;

 SELECT d.DepartamentoId Id,d.Nombre,ISNULL(b.Budget,0)Budget,ISNULL(e.Pending,0)Pending,ISNULL(e.Real,0)Real,ISNULL(b.Budget,0)-ISNULL(e.Real,0)Available,CAST(CASE WHEN ISNULL(b.Budget,0)=0 THEN 0 ELSE ISNULL(e.Real,0)/b.Budget*100 END AS DECIMAL(9,2))ExecutionPercent
 FROM dbo.DepartamentosOperativos d OUTER APPLY(SELECT SUM(MontoAsignado)Budget FROM #B WHERE DepartamentoId=d.DepartamentoId)b OUTER APPLY(SELECT SUM(CASE WHEN Estado=N'Registrado'THEN Total ELSE 0 END)Pending,SUM(CASE WHEN Estado IN(N'Aprobado',N'Pagado')THEN Total ELSE 0 END)Real FROM #E WHERE DepartamentoId=d.DepartamentoId)e
 WHERE d.Activo=1 AND(@DepartamentoId IS NULL OR d.DepartamentoId=@DepartamentoId) ORDER BY d.Nombre;

 SELECT c.CategoriaId Id,c.Nombre,ISNULL(b.Budget,0)Budget,ISNULL(e.Pending,0)Pending,ISNULL(e.Real,0)Real,ISNULL(b.Budget,0)-ISNULL(e.Real,0)Available,CAST(CASE WHEN ISNULL(b.Budget,0)=0 THEN 0 ELSE ISNULL(e.Real,0)/b.Budget*100 END AS DECIMAL(9,2))ExecutionPercent
 FROM dbo.CategoriasGasto c OUTER APPLY(SELECT SUM(MontoAsignado)Budget FROM #B WHERE CategoriaId=c.CategoriaId)b OUTER APPLY(SELECT SUM(CASE WHEN Estado=N'Registrado'THEN Total ELSE 0 END)Pending,SUM(CASE WHEN Estado IN(N'Aprobado',N'Pagado')THEN Total ELSE 0 END)Real FROM #E WHERE CategoriaId=c.CategoriaId)e
 WHERE c.Activo=1 AND(@CategoriaId IS NULL OR c.CategoriaId=@CategoriaId) ORDER BY c.Nombre;

 ;WITH meses AS(SELECT Mes FROM(VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12))m(Mes))
 SELECT m.Mes,ISNULL(b.Budget,0)Budget,ISNULL(e.Pending,0)Pending,ISNULL(e.Real,0)Real FROM meses m
 OUTER APPLY(SELECT SUM(MontoAsignado)Budget FROM #B WHERE Mes=m.Mes)b OUTER APPLY(SELECT SUM(CASE WHEN Estado=N'Registrado'THEN Total ELSE 0 END)Pending,SUM(CASE WHEN Estado IN(N'Aprobado',N'Pagado')THEN Total ELSE 0 END)Real FROM #E WHERE MONTH(FechaGasto)=m.Mes)e ORDER BY m.Mes;

 ;WITH detalle AS(SELECT *,COUNT(*)OVER()TotalResultados FROM #E)
 SELECT * FROM detalle ORDER BY FechaGasto DESC,GastoId DESC OFFSET(@Pagina-1)*@TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
 SELECT DepartamentoId,Nombre FROM dbo.DepartamentosOperativos WHERE Activo=1 ORDER BY Nombre;
 SELECT CategoriaId,Nombre FROM dbo.CategoriasGasto WHERE Activo=1 ORDER BY Nombre;
END;
GO

IF OBJECT_ID(N'dbo.sp_BudgetComparison_Dashboard',N'P') IS NULL THROW 54490,N'Validación posterior 0011 fallida.',1;
GO
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0011_budget_actual_comparison')
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)VALUES(N'0011_budget_actual_comparison',N'0011_budget_actual_comparison.sql',CONVERT(CHAR(64),HASHBYTES('SHA2_256',N'0011_budget_actual_comparison_v1'),2),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-223: presupuesto versus real, pendientes separados, proyección determinista y drill-down.');
GO
